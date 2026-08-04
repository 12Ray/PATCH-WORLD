param([string]$OutputRoot = "assets/audio")

$sampleRate = 22050

function Write-Tone {
  param(
    [string]$Path,
    [double]$Frequency,
    [double]$Duration,
    [double]$Volume = 0.18
  )

  $samples = [int]($sampleRate * $Duration)
  $dataLength = $samples * 2
  $stream = [System.IO.File]::Create($Path)
  $writer = [System.IO.BinaryWriter]::new($stream)
  try {
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
    $writer.Write([int](36 + $dataLength))
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("WAVEfmt "))
    $writer.Write([int]16)
    $writer.Write([int16]1)
    $writer.Write([int16]1)
    $writer.Write([int]$sampleRate)
    $writer.Write([int]($sampleRate * 2))
    $writer.Write([int16]2)
    $writer.Write([int16]16)
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
    $writer.Write([int]$dataLength)
    for ($index = 0; $index -lt $samples; $index += 1) {
      $time = $index / $sampleRate
      $fade = [Math]::Min(1, [Math]::Min($time * 20, ($Duration - $time) * 20))
      $wave = [Math]::Sin(2 * [Math]::PI * $Frequency * $time)
      $writer.Write([int16]($wave * 32767 * $Volume * $fade))
    }
  } finally {
    $writer.Dispose()
    $stream.Dispose()
  }
}

$bgmPath = Join-Path $OutputRoot "bgm"
$sfxPath = Join-Path $OutputRoot "sfx"
New-Item -ItemType Directory -Force -Path $bgmPath, $sfxPath | Out-Null

Write-Tone (Join-Path $bgmPath "archive_hum.wav") 55 4 0.08
Write-Tone (Join-Path $bgmPath "optimizer_layer.wav") 82.41 4 0.08

$effects = @{
  "patch_pulse.wav" = 740
  "damage.wav" = 120
  "heal.wav" = 520
  "overflow_warning.wav" = 310
  "overflow_blast.wav" = 75
  "time_freeze.wav" = 880
  "frame_burst.wav" = 990
  "terminal.wav" = 660
  "ui_confirm.wav" = 440
}

foreach ($entry in $effects.GetEnumerator()) {
  Write-Tone (Join-Path $sfxPath $entry.Key) $entry.Value 0.18 0.16
}
