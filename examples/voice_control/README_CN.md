# 在 RV1126B 上落地 Voice Control —— 从零起步操作手册

本手册带你从**一台什么都没装的交叉编译机 + 一块 RV1126B 板子**起步,一步步把
「语音指令控制 + 中文语音反馈」的闭环跑通。所有步骤均在 ATK-DLRV1126B（正点原子）
+ Ubuntu 20.04 交叉编译机上**实测验证**通过。

> 英文简版见 [README.md](README.md)。

---

## 0. 这是个什么东西

闭环数据流：

```
麦克风(arecord) ─► 数字增益(归一化) ─► zipformer ASR ─► 关键词匹配 ─┬─► 执行动作(GPIO/串口/API)
                                                                     └─► aplay 播放固定中文反馈 wav
```

- **ASR（听）**：用 zipformer（中英双语流式语音识别），把语音转成文字。
- **反馈（说）**：反馈语句是**固定有限的几句**（如「灯已打开 / 灯已关闭 / 抱歉，没有听清」），
  所以在 PC 上**预先生成好中文 wav**，板子上识别后直接播放对应那一段——无需在板上做中文 TTS。
- 本阶段**不使用 mms_tts**：它只支持英文，且 C++ 分词器写死英文。中文动态合成是后续工作。

### 两台机器，分工要分清

| 工作 | 在哪台 | 说明 |
|---|---|---|
| onnx→rknn 模型转换 | **交叉编译机（x86 Linux）** | 需 RKNN-Toolkit2 2.3.2 |
| 交叉编译 demo | **交叉编译机** | 需 aarch64 工具链 |
| 生成中文反馈 wav | **交叉编译机** | edge-tts + ffmpeg |
| 运行闭环 | **RV1126B 板子** | arecord/aplay + demo |

下文统一称两台机器为 **PC**（交叉编译机）和 **板子**（RV1126B）。

---

## 1. 前置条件

- **PC**：x86_64 Ubuntu（实测 20.04，Python 3.8），能访问外网。
- **板子**：RV1126B，已烧录可启动的 Linux 系统，能 SSH 登录，接好**麦克风**和**喇叭**。
- **版本要求（重要）**：rknn_model_zoo 用 **V2.3.2**；板子 librknnrt、PC 的 RKNN-Toolkit2
  三者都要 **≥ 2.3.2 且尽量同版本**。RV1126B 是 V2.3.2 起才正式支持的。

> RV1126B 用的是**新的 RKNPU2 工具链**（RKNN-Toolkit2），和老 RV1126（RKNPU1）不是一回事，别搞混。

---

## 2. 第一步：检查板子环境（在板子上执行）

```sh
# 2.1 确认 NPU runtime 版本（必须 ≥ 2.3.2）
strings /usr/lib/librknnrt.so | grep -i 'librknnrt version'
# 期望类似：librknnrt version: 2.3.2 (xxxx@2025-04-09...)

# 2.2 确认内核 NPU 驱动存在
dmesg | grep -i rknpu | grep -i version

# 2.3 确认音频工具和设备
which arecord aplay
arecord -l    # 应列出 capture 设备(麦克风)
aplay -l      # 应列出 playback 设备(喇叭)
```

只要 librknnrt ≥ 2.3.2、且 `arecord -l` / `aplay -l` 各能看到声卡，就可以继续。

> **关键坑①（ALSA 设备）**：很多板子（含本例 ES8389 codec）用 `arecord -D plughw:0,0`
> 会报 `Input/output error`。**请用默认设备**（命令不加 `-D`），它能正常以 16k 单声道录音。

---

## 3. PC：安装 RKNN-Toolkit2（转模型用）

转换 onnx→rknn 必须有 RKNN-Toolkit2（x86 Python 包）。建议用 venv 隔离。

```sh
# 3.1 venv 需要的系统包（Ubuntu 缺 ensurepip 时）
sudo apt-get install -y python3.8-venv

# 3.2 建 venv
python3 -m venv ~/rknnenv
source ~/rknnenv/bin/activate
python -m pip install --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple/

# 3.3 装依赖（用清华源加速）
pip install -i https://pypi.tuna.tsinghua.edu.cn/simple/ \
  "numpy<=1.26.4" "protobuf>=4.21.6,<=4.25.4" psutil "ruamel.yaml>=0.17.4" \
  "scipy>=1.5.4" "tqdm>=4.64.0" "fast-histogram>=0.11" "onnx>=1.16.1" "onnxruntime>=1.10.0"

# 3.4 装 RKNN-Toolkit2 2.3.2 的 x86_64 wheel
#     正点原子 SDK 里自带：~/atk-dlrv1126b-sdk/external/rknn-toolkit2/rknn-toolkit2/packages/x86_64/
#     选与 Python 版本匹配的（py3.8 → cp38）。也可从 Rockchip 官方获取对应 2.3.2 wheel。
pip install --no-deps ~/atk-dlrv1126b-sdk/external/rknn-toolkit2/rknn-toolkit2/packages/x86_64/rknn_toolkit2-2.3.2-cp38-*_x86_64.whl

# 3.5 RKNN-Toolkit2 还硬依赖 torch 和 cv2（即使只做 onnx 转换也要）
pip install "torch==2.4.0" --index-url https://download.pytorch.org/whl/cpu   # CPU 版即可，体积小
pip install -i https://pypi.tuna.tsinghua.edu.cn/simple/ opencv-python-headless

# 3.6 验证
python -c "from rknn.api import RKNN; print('RKNN_OK')"
```

> **关键坑②（隐藏依赖）**：`from rknn.api import RKNN` 会连带 `import torch` 和 `import cv2`，
> 不装会报 `ModuleNotFoundError`。装 **CPU 版 torch**（约 190MB）即可，别装默认的 CUDA 版（近 1GB）。

---

## 4. PC：准备仓库 + 下载 onnx 模型

```sh
# 4.1 获取 rknn_model_zoo（V2.3.2）。可 git clone，或从已有仓库拷贝。
#     国内 clone github 可能很慢，建议用已有仓库或镜像。
cd ~
git clone --depth 1 https://github.com/airockchip/rknn_model_zoo.git
cd rknn_model_zoo

# 4.2 下载 zipformer 的 3 个 onnx
cd examples/zipformer/model
bash download_model.sh          # 拉 encoder / decoder / joiner 三个 onnx
ls -la *.onnx
```

> **省空间提示**：`3rdparty/opencv`（约 523MB）对本例（纯音频）**用不到**，
> 拷贝/打包仓库时可排除它，3rdparty 只需 rknpu2 / kaldi_native_fbank / libsndfile / fftw / librga / jpeg_turbo。

---

## 5. PC：转换模型 onnx → rknn（rv1126b）

```sh
source ~/rknnenv/bin/activate
cd ~/rknn_model_zoo/examples/zipformer/python

python convert.py ../model/encoder-epoch-99-avg-1.onnx rv1126b
python convert.py ../model/decoder-epoch-99-avg-1.onnx rv1126b
python convert.py ../model/joiner-epoch-99-avg-1.onnx  rv1126b

ls -la ../model/*.rknn   # 应生成 3 个 .rknn（encoder 约 112MB）
```

- zipformer 默认用 **fp（不量化）**，无需校准数据集。

---

## 6. PC：交叉编译 demo（aarch64）

RV1126B 是 **aarch64**。需要一个 aarch64 交叉工具链。正点原子 SDK 里现成有两套，推荐用
prebuilt 的 gcc-arm 10.3（版本接近官方推荐、编译更稳；其 glibc 向前兼容板子）。

```sh
cd ~/rknn_model_zoo

# 指定工具链前缀（按你的 SDK 路径调整）
export GCC_COMPILER=~/atk-dlrv1126b-sdk/prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu

# 编译 zipformer
bash ./build-linux.sh -t rv1126b -a aarch64 -d zipformer
```

产物在：`install/rv1126b_linux_aarch64/rknn_zipformer_demo/`
（含可执行文件 `rknn_zipformer_demo`、`lib/`、`model/`，模型已自动拷入）。

> 若提示找不到 `aarch64-...-gcc`，检查 `GCC_COMPILER` 路径；若 `build-linux.sh` 报权限不够，
> 用 `bash ./build-linux.sh ...` 调用即可。

---

## 7. PC：生成固定中文反馈 wav

```sh
sudo apt-get install -y ffmpeg
source ~/rknnenv/bin/activate
pip install -i https://pypi.tuna.tsinghua.edu.cn/simple/ edge-tts

cd ~/rknn_model_zoo/examples/voice_control
python gen_feedback.py          # 生成 feedback/light_on.wav 等(16k 单声道 s16)
ls -la feedback/
```

- 默认生成「灯已打开 / 灯已关闭 / 抱歉，没有听清」三句。改 `gen_feedback.py` 里的 `PHRASES` 即可增删，
  但**基名要和 `voice_control.sh` 里引用的一致**（light_on / light_off / not_understood）。
- 没网/装不了 edge-tts？用任意中文 TTS 或直接录音都行，只要最终是 16k 单声道 wav、文件名对得上。

---

## 8. 部署到板子

把以下内容拷到板子（用 `scp` 或 `adb push`；下面以 scp 为例，IP 换成你板子的）：

```sh
BOARD=root@<板子IP>

# 8.1 demo（可执行 + lib + 模型）
scp -r ~/rknn_model_zoo/install/rv1126b_linux_aarch64/rknn_zipformer_demo  $BOARD:/data/

# 8.2 voice_control 脚本 + 反馈音频 + 归一化脚本
ssh $BOARD "mkdir -p /data/voice_control"
cd ~/rknn_model_zoo/examples/voice_control
scp -r feedback            $BOARD:/data/voice_control/
scp voice_control.sh       $BOARD:/data/voice_control/
scp normalize_wav.py       $BOARD:/data/voice_control/
```

到板子上修正权限（若脚本来自 Windows，先去掉换行符 \r）：

```sh
# 在板子上
cd /data/voice_control
sed -i 's/\r$//' voice_control.sh normalize_wav.py
chmod +x voice_control.sh
```

---

## 9. 板子：单点验证（出问题好定位）

**别一上来就跑整脚本**，先逐段确认：

```sh
# 9.1 验 ASR（用 demo 自带 test.wav，不碰麦克风）
cd /data/rknn_zipformer_demo && export LD_LIBRARY_PATH=./lib
./rknn_zipformer_demo model/encoder-epoch-99-avg-1.rknn model/decoder-epoch-99-avg-1.rknn \
                      model/joiner-epoch-99-avg-1.rknn model/test.wav
# 期望输出：Zipformer output: 对我做了介绍那么我想说的是大家如果对我的研究感兴趣呢

# 9.2 验录音+回放（确认麦克风、喇叭都通）
arecord -f S16_LE -r 16000 -c 1 -d 3 /tmp/t.wav   # 录 3 秒(默认设备，别加 -D plughw)
aplay /tmp/t.wav                                   # 应能听到刚才录的声音
```

9.1、9.2 都过了，再进下一步。

---

## 10. 板子：运行闭环

```sh
/data/voice_control/voice_control.sh
```

按回车 → 对麦克风**清楚地**说「开灯」/「关灯」→ 听到对应中文反馈。正常输出类似：

```
[ready] press Enter, then speak...
[asr] recognized: "开灯"
[action] turn light ON
```

---

## 11. 关键坑与排错

### 坑③：说了话却反馈「抱歉，没有听清」，识别结果为空
**原因**：板载麦克风录音电平偏低（实测峰值约 19%、RMS ~380），语音能量不足，
zipformer 输出全空。板子采集音量通常已到顶（`amixer` 里 Capture 已 100%），没法再调。

**修复（本例已内置）**：在「录音 → 识别」之间加一道**数字增益**——`voice_control.sh`
的 `recognize()` 会先调用 `normalize_wav.py` 把录音峰值归一化到 ~90%（上限 12 倍）再喂给 ASR。

自助诊断单次录音：
```sh
# 录 4 秒，看电平 + 识别结果
arecord -f S16_LE -r 16000 -c 1 -d 4 /tmp/dbg.wav
python3 /data/voice_control/normalize_wav.py /tmp/dbg.wav /tmp/dbg_n.wav 0.9 12
cd /data/rknn_zipformer_demo && export LD_LIBRARY_PATH=./lib
./rknn_zipformer_demo model/encoder-epoch-99-avg-1.rknn model/decoder-epoch-99-avg-1.rknn \
                      model/joiner-epoch-99-avg-1.rknn /tmp/dbg_n.wav | grep 'Zipformer output:'
```

### 其它常见问题
| 现象 | 可能原因 | 处理 |
|---|---|---|
| `arecord ... -D plughw:0,0` 报 I/O error | codec 不支持该直连 | 改用默认设备（不加 `-D`） |
| 识别成同音字/带空格（如「开 灯」） | 发音/分词差异 | 在 `voice_control.sh` 的 `case` 里加该变体关键词 |
| 模型 init 失败/版本不匹配 | 板子 runtime 与转换工具版本不一致 | 确保两端都 2.3.2 |
| 识别仍偶尔为空 | 声音太小/离麦远 | 离近些、大声说；必要时调大 `normalize_wav.py` 的上限倍数 |

---

## 12. 接真实硬件

编辑板子上的 `/data/voice_control/voice_control.sh`，把 `do_action()` 里的 `echo`
换成实际控制命令，例如：

```sh
light_on)  echo 1 > /sys/class/leds/你的led/brightness ;;
light_off) echo 0 > /sys/class/leds/你的led/brightness ;;
```

（或 `gpioset`、串口 `echo > /dev/ttySx`、HTTP 调用等。）

---

## 13. 后续（动态中文 TTS）

如果反馈内容需要**动态合成任意中文**（播报数字、时间、任意文本），需要做一个常驻 C++ 进程
（模型只加载一次、ALSA 直接录放），并移植中文 TTS。自带的 `mms_tts` 仅支持英文且分词器写死英文，
中文路线需重写 tokenizer + uroman 罗马化 + 重导出 `mms-tts-cmn`，工作量较大，超出本验证阶段范围。
