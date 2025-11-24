import os
import sounddevice as sd
import soundfile as sf
import numpy as np
import time


class VoiceTriggerManager:
    def __init__(self, base_path="voice_samples"):
        self.base_path = base_path
        os.makedirs(self.base_path, exist_ok=True)

        self.trigger_phrases = {
            "google": "hey_google_pause.wav",
            "siri": "hey_siri_pause.wav",
            "alexa": "alexa_pause.wav",
        }
        self.user_voice_samples = {}  # 사용자 음성 샘플 경로 저장
        self.samplerate = 44100  # 샘플링 레이트

    def get_voice_path(self, device_type, command="pause"):
        """사용자 음성 파일 경로를 가져옵니다."""
        return self.user_voice_samples.get(device_type, {}).get(command)

    def play_voice_trigger(self, device_type="google", command="pause"):
        """
        사용자 목소리로 녹음된 음성 명령어를 재생합니다.
        """
        trigger_file_path = self.get_voice_path(device_type, command)

        if trigger_file_path and os.path.exists(trigger_file_path):
            try:
                data, fs = sf.read(trigger_file_path, dtype="float32")
                sd.play(data, fs)
                sd.wait()
                print(f"🎤 음성 트리거 재생: {trigger_file_path}")
                return True
            except Exception as e:
                print(f"⚠️ 음성 재생 실패: {e}")
                return False
        else:
            print(f"⚠️ 녹음된 음성 없음: {device_type} - {command}")
            return False

    def record_user_voice(self, device_type, command, duration=3):
        """
        사용자 목소리로 음성 명령어를 녹음하여 저장합니다.
        """
        try:
            print(f"🎙️ '{device_type} {command}' 녹음을 시작합니다... ({duration}초)")
            recording = sd.rec(
                int(duration * self.samplerate),
                samplerate=self.samplerate,
                channels=1,
                dtype="float32",
            )
            sd.wait()  # 녹음이 끝날 때까지 대기

            filename = f"user_{device_type}_{command}_{int(time.time())}.wav"
            filepath = os.path.join(self.base_path, filename)

            sf.write(filepath, recording, self.samplerate)

            if device_type not in self.user_voice_samples:
                self.user_voice_samples[device_type] = {}
            self.user_voice_samples[device_type][command] = filepath

            print(f"✅ 녹음 완료 및 저장: {filepath}")
            return filepath
        except Exception as e:
            print(f"⚠️ 녹음 실패: {e}")
            return None
