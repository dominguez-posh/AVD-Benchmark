# AVD-Benchmark

Stand-alone performance benchmark for Azure Virtual Desktop session hosts.

Status: this script is being replaced by the benchmark engine of AVDTune (https://github.com/dominguez-posh/AVDTune); this repository will carry its stand-alone version.

## diskspd

DiskSpd is not included (its binary release may not be redistributed). Download it from Microsoft (https://github.com/microsoft/diskspd/releases), check its signature, and put `diskspd.exe` next to the script.

## Usage

Run in Windows PowerShell as administrator:

    .\Invoke-avdperfocmancebenchmark.ps1 -SMBShare \<storageaccount>.file.core.windows.net\<share>\fslogixbenchmark

## License

MIT, see LICENSE.
