echo off
start /d "C:\Program Files\HWiNFO64" HWiNFO64.EXE
timeout 15
start /d "C:\Program Files (x86)\Geeks3D\Benchmarks\FurMark\" FurMark.exe /width=1920 /height=1080 /msaa=4 /nogui /nomenubar /noscore /run_mode=2 /disable_catalyst_warning /max_frames=-1
timeout 20
start /d "C:\Program Files\JAM Software\HeavyLoad\" HeavyLoad.exe /start /cpu