# wg2ws-converter
PowerShell script to configure WireSock for DNS leak-proof partial tunneling using WireGuard configs.

## Key Features

- Modifies WireGuard config files for optimal use with WireSock partial tunneling
- Implements client-side measures to prevent DNS and traffic leaks in partial tunnel mode
- Allows custom IP ranges and domain routing through the VPN
- Adds PostUp and PostDown scripts for robust DNS management and routing control
- Handles FQDN resolution and IPv4/IPv6 differentiation
- Provides clear warnings for potential configuration issues

## Description

This PowerShell script enhances WireGuard configuration files for use with WireSock's partial tunneling feature. It addresses the challenge of maintaining a leak-proof VPN connection when using WireSock's partial tunneling, which is not inherently leak-proof like a full WireGuard tunnel. The script focuses on implementing client-side measures to prevent DNS and traffic leaks while allowing the flexibility of partial tunneling.

## Usage

1. Ensure you have PowerShell installed on your Windows system.
2. Download the `WG2WSConverter.ps1` script to your local machine.
3. Open a PowerShell window with administrator privileges.
4. Navigate to the directory containing the script.
5. Run the script using the following command:
	powershell.exe -ExecutionPolicy Bypass -File .\WG2WSConverter.ps1
6. Follow the prompts to input your WireGuard configuration file path and specify the output path for the WireSock configuration.
7. Enter the IP ranges, websites, or IPs you want to route through the VPN when prompted.
8. The script will generate a new WireSock configuration file with the necessary modifications.

## Requirements

- Windows operating system
- PowerShell 5.1 or later
- Administrator privileges (required for modifying network routes)
- Existing WireGuard configuration file
- [WireSock client]([url](https://www.wiresock.net/)) installed on the system

## Limitations

- This script does not include options for allowing specific apps through the VPN or disallowing certain traffic. These features are not implemented as they were not required by the author.
- The script assumes that the server-side configuration is already secure and focuses on enhancing client-side security for partial tunneling scenarios.
- IPv6 addresses are not supported and will be skipped if entered.

## Contributing

Contributions to improve the script or extend its functionality are welcome. Please feel free to submit issues or pull requests on the GitHub repository.

## License

This project is licensed under the GNU General Public License v2.0 - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This script modifies network configurations and routing tables. While it's designed to enhance security, please ensure you understand the changes it makes to your system. Always backup your original configurations before using this script.

## Author

Anton Luu

## Acknowledgments

- WireGuard® is a registered trademark of Jason A. Donenfeld.
- WireSock is developed and maintained by WireGuard LLC.
