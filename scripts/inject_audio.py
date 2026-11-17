"""Streams raw 44.1 kHz mono s16le PCM into the Android emulator's virtual microphone over its gRPC
EmulatorController.injectAudio API, paced in real time.

Usage: inject_audio.py STUBS_DIR PCM_FILE [PORT]
STUBS_DIR holds emulator_controller_pb2*.py generated from the emulator's own emulator_controller.proto.
"""
import sys
import time

stubs, pcm_path = sys.argv[1], sys.argv[2]
port = sys.argv[3] if len(sys.argv) > 3 else "8554"
sys.path.insert(0, stubs)

import grpc  # noqa: E402
import emulator_controller_pb2 as pb  # noqa: E402
import emulator_controller_pb2_grpc as rpc  # noqa: E402

RATE, BYTES_PER_SECOND = 44100, 44100 * 2
CHUNK = BYTES_PER_SECOND // 50  # 20 ms

fmt_fields = pb.AudioFormat.DESCRIPTOR.fields_by_name
kwargs = {"samplingRate": RATE, "channels": pb.AudioFormat.Mono, "format": pb.AudioFormat.AUD_FMT_S16}
if "mode" in fmt_fields and hasattr(pb.AudioFormat, "MODE_REAL_TIME"):
    kwargs["mode"] = pb.AudioFormat.MODE_REAL_TIME
fmt = pb.AudioFormat(**kwargs)
pcm = open(pcm_path, "rb").read()


def packets():
    start = time.time()
    for i in range(0, len(pcm), CHUNK):
        yield pb.AudioPacket(format=fmt, timestamp=int((start + i / BYTES_PER_SECOND) * 1e6), audio=pcm[i:i + CHUNK])
        wait = start + (i + CHUNK) / BYTES_PER_SECOND - time.time()
        if wait > 0:
            time.sleep(wait)


stub = rpc.EmulatorControllerStub(grpc.insecure_channel(f"localhost:{port}"))
stub.injectAudio(packets(), timeout=60)
print(f"injected {len(pcm) / BYTES_PER_SECOND:.1f} s of audio over gRPC ({', '.join(kwargs)})")
