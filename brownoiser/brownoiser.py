import threading
import time
import pygame
from pystray import Icon as TrayIcon, Menu as TrayMenu, MenuItem as TrayMenuItem
from PIL import Image
import sys
import os


def resource_path(relative_path):
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")
    return os.path.join(base_path, relative_path)


AUDIO_FILE = resource_path('brownnoise_sample1.wav')
ICON_FILE = resource_path('bnor_MacOS_Icon.icns')
FADE_TIME_MS = 2000


class NoisePlayer:

    def __init__(self):
        print("NoisePlayer: Loading...")
        self.audio_sound = None
        self.channel_a = None
        self.channel_b = None
        self.is_playing = False
        self.playback_thread = None
        self.stop_event = threading.Event()
        self.master_volume = 1.0
        self.active_channel = None

        self.initialized = self._setup_audio()


    def _setup_audio(self):
        try:
            pygame.mixer.init()
            self.audio_sound = pygame.mixer.Sound(AUDIO_FILE)
            self.channel_a = pygame.mixer.Channel(0)
            self.channel_b = pygame.mixer.Channel(1)
            print(f"NoisePlayer: Audio {AUDIO_FILE} Loaded")
            return True
        except pygame.error as e:
            print(f"Error: unable to load {AUDIO_FILE}")
            print(f"Pygame error: {e}")
            return False

    def _manual_fade_in(self, channel, duration_ms):
        """0 -> master_volume in single thread"""
        try:
            steps = 50
            sleep_time_sec = (duration_ms / 1000.0) / steps
            channel.set_volume(0.0)
            for i in range(1, steps + 1):
                if self.stop_event.is_set():
                    channel.set_volume(0.0)
                    return
                current_target_volume = self.master_volume
                volume = (i / steps) * current_target_volume
                channel.set_volume(volume)
                time.sleep(sleep_time_sec)
            if not self.stop_event.is_set():
                channel.set_volume(self.master_volume)
        except Exception:
            pass

    def _start_manual_fade_in(self, channel, duration_ms):
        fade_thread = threading.Thread(target=self._manual_fade_in, args=(channel, duration_ms), daemon=True)
        fade_thread.start()

    def _manual_fade_out(self, channel, duration_ms):
        """non-linear fade-in & fade-out operations"""
        try:
            start_time = time.time()
            phase1_duration_ms = 1500.0
            phase2_duration_ms = max(0.0, duration_ms - phase1_duration_ms)
            while True:
                if self.stop_event.is_set():
                    channel.set_volume(0.0)
                    return
                elapsed_ms = (time.time() - start_time) * 1000.0
                current_start_volume = self.master_volume
                if elapsed_ms < phase1_duration_ms:
                    progress = elapsed_ms / phase1_duration_ms
                    vol_multiplier = 1.0 - (progress * 0.5)
                elif elapsed_ms < duration_ms:
                    progress = (elapsed_ms - phase1_duration_ms) / phase2_duration_ms
                    vol_multiplier = 0.5 - (progress * 0.5)
                else:
                    break
                channel.set_volume(vol_multiplier * current_start_volume)
                time.sleep(0.02)
            channel.stop()
        except Exception:
            pass

    def _start_manual_fade_out(self, channel, duration_ms):
        fade_thread = threading.Thread(target=self._manual_fade_out, args=(channel, duration_ms), daemon=True)
        fade_thread.start()

    def _playback_manager(self):
        audio_length_ms = int(self.audio_sound.get_length() * 1000)
        wait_time_ms = audio_length_ms - FADE_TIME_MS

        if wait_time_ms < 0:
            current_fade_time = 0
        else:
            current_fade_time = FADE_TIME_MS

        print("DJ：Initialized")
        self.channel_a.play(self.audio_sound, loops=0)
        self._start_manual_fade_in(self.channel_a, current_fade_time)
        self.active_channel = 'a'

        while self.is_playing and not self.stop_event.is_set():
            interrupted = self.stop_event.wait(timeout=wait_time_ms / 1000.0)
            if interrupted or not self.is_playing or self.stop_event.is_set():
                break

            print("DJ：crossfading...")
            if self.active_channel == 'a':
                if current_fade_time > 0:
                    self._start_manual_fade_out(self.channel_a, current_fade_time)
                else:
                    self.channel_a.stop()
                self.channel_b.play(self.audio_sound, loops=0)
                self._start_manual_fade_in(self.channel_b, current_fade_time)
                self.active_channel = 'b'
            else:
                if current_fade_time > 0:
                    self._start_manual_fade_out(self.channel_b, current_fade_time)
                else:
                    self.channel_b.stop()
                self.channel_a.play(self.audio_sound, loops=0)
                self._start_manual_fade_in(self.channel_a, current_fade_time)
                self.active_channel = 'a'

        print("DJ：clearing environment...")
        self.channel_a.stop()
        self.channel_b.stop()
        self.is_playing = False
        self.active_channel = None
        print("DJ：thread exited")


    def play(self):
        if not self.is_playing:
            print("NoisePlayer: 'Play' detected")
            self.is_playing = True
            self.stop_event.clear()
            self.playback_thread = threading.Thread(target=self._playback_manager, daemon=True)
            self.playback_thread.start()

    def stop(self):
        if self.is_playing:
            print("NoisePlayer:  'Stop' detected")
            self.is_playing = False
            self.stop_event.set()
            if self.playback_thread and self.playback_thread.is_alive():
                self.playback_thread.join(timeout=2.0)
            print("NoisePlayer: Stopped")

    def set_volume(self, v):
        self.master_volume = v
        print(f"NoisePlayer: volume set to {self.master_volume * 100:.0f}%")

        if self.is_playing:
            # 检查是否*不*在交叉淡入淡出（即只有一个通道在忙）
            is_fading = self.channel_a.get_busy() and self.channel_b.get_busy()
            if not is_fading:
                if self.active_channel == 'a' and self.channel_a.get_busy():
                    self.channel_a.set_volume(self.master_volume)
                elif self.active_channel == 'b' and self.channel_b.get_busy():
                    self.channel_b.set_volume(self.master_volume)



player = None
tray_icon = None


# --- 5. UI "Controller" ---

def play_audio_ui():
    """click play to use"""
    if player:
        player.play()
    if tray_icon:
        tray_icon.menu = create_menu()


def stop_audio_ui():
    if player:
        player.stop()
    if tray_icon:
        tray_icon.menu = create_menu()


def set_volume_ui(v):
    if player:
        player.set_volume(v)
    if tray_icon:
        tray_icon.menu = create_menu()


def quit_app():
    print("Exiting...")
    if player:
        player.stop()
    if tray_icon:
        tray_icon.stop()


# --- 6. UI ---

def create_menu():
    if player and player.is_playing:
        play_stop_item = TrayMenuItem('Stop', stop_audio_ui)
    else:
        play_stop_item = TrayMenuItem('Start', play_audio_ui)

    current_volume = player.master_volume if player else 1.0

    vol_menu_items = (
        TrayMenuItem('100%', lambda: set_volume_ui(1.0),
                     checked=lambda item: current_volume == 1.0, radio=True),
        # TrayMenuItem('80%', lambda: set_volume_ui(0.8),
        #              checked=lambda item: current_volume == 0.8, radio=True),
        TrayMenuItem('60%', lambda: set_volume_ui(0.6),
                     checked=lambda item: current_volume == 0.6, radio=True),
        # TrayMenuItem('40%', lambda: set_volume_ui(0.4),
        #              checked=lambda item: current_volume == 0.4, radio=True),
        TrayMenuItem('20%', lambda: set_volume_ui(0.2),
                     checked=lambda item: current_volume == 0.2, radio=True),
        TrayMenu.SEPARATOR,
        TrayMenuItem('Mute', lambda: set_volume_ui(0.0),
                     checked=lambda item: current_volume == 0.0, radio=True)
    )

    menu_items = (
        play_stop_item,
        TrayMenuItem('Volume', TrayMenu(*vol_menu_items)),
        TrayMenu.SEPARATOR,
        TrayMenuItem('Exit', quit_app)
    )
    return TrayMenu(*menu_items)


def run_tray_icon():
    """Tray icon initialization"""
    global tray_icon
    try:
        image = Image.open(ICON_FILE)
    except FileNotFoundError:
        print(f"icon not found: {ICON_FILE}")
        return
    except Exception as e:
        print(f"Error while loading icon: {e}")
        return

    tray_icon = TrayIcon(
        'Brownoiser_Alpha_(v0.0.1)',
        image,
        'Brownoiser_Alpha_(v0.0.1)',
        menu=create_menu()
    )

    print("Tray icon initialized")
    tray_icon.run()



if __name__ == "__main__":

    player = NoisePlayer()
    if not player.initialized:
        input("Initialization failed. Press Enter to continue...")
    else:
        run_tray_icon()

    print("Program Stopped")