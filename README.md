# AWS SSM Connection Script

[Docker hub image](https://hub.docker.com/r/gunslito/aws-ssm-session)
## TL;DR
You need to have **Docker** installed and **AWS CLI configured with profiles** in your **host**.

Command to run directly from docker hub repository
```bash
docker run --rm -it -v "$HOME/.aws:/root/.aws:ro" aws-ssm-session
```

## Description
Bash script to easily start **SSM sessions** with AWS instances. It supports **AWS profile selection**, **instance filtering**, and **automatic SSO token management**.

## Features
- **Interactive AWS profile selection** (or specify via `-p` flag).
- **Interactive AWS instance selection** (or specify via `-i` flag).
- **Instance selection** based on tags (`ssm:enabled`, running state).
- **Automatic SSO login/logout handling** if the session expires.
- **Direct command suggestion** for reconnecting (helpful for creating aliases).
- **Run via Docker if you have trouble with your OS** (it mounts your ~/.aws folder into the container in read only mode).

## Local host requirements
- [**AWS cli v2**](https://github.com/aws/aws-cli.git)
- [**Session manager plugin**](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
- **Bash version 5.1.16(1)-release (x86_64-pc-linux-gnu)+**
- **Docker** (optional for docker image)

## AWS Requirements
- The **instance** must have the [Amazon SSM agent](https://docs.aws.amazon.com/systems-manager/latest/userguide/manually-install-ssm-agent-linux.html) correctly installed.
- The **instance** must have an outbound connection (HTTPS/443) to the AWS-SSM network or `0.0.0.0/0`.
- The **instance** must have the necessary [IAM role](https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-instance-permissions.html) with SSM permissions. You can use these AWS-managed policies:
    * `AmazonSSMManagedInstanceCore` (Required for SSM to function correctly).
    * `CloudWatchAgentServerPolicy` (Required for SSM to upload session logs to CloudWatch).
- The instance must have the tag with the key:value "*ssm:enabled*" and must be in *running state*.


## Installation
You can copy aws-ssm-session.sh and execute directly, but if you don't have everything installed you can follow these steps:

### 1. Clone the repository
```bash
git clone https://github.com/Gunslito/aws-ssm-session.git
cd aws-ssm-session
```

### 2. Make the script executable
```bash
chmod +x aws-ssm-session.sh
```

### 3. Create an alias for quick access (Optional)
To use the script from anywhere, add this line to your `~/.bashrc` or `~/.zshrc`:
```bash
alias aws-ssm-session='~/aws-ssm-session/aws-ssm-session.sh'
```
Then apply the changes:
```bash
source ~/.bashrc  # or source ~/.zshrc
```

## Running with Docker
If you prefer running the script inside a Docker container, build the image and execute it as follows:

### 1. Build the Docker image
```bash
docker build -t aws-ssm-session .
```

### 2. Run the script in a container
```bash
docker run --rm -it \
    -v "$HOME/.aws:/root/.aws:ro" \
    aws-ssm-session
```

### 3. Docker parameteres
- `-v "$HOME/.aws:/root/.aws:ro"` → Mounts AWS credentials for authentication.
- `--rm` → Ensures the container is removed after execution.

## Usage
You can now run the script using:
```bash
aws-ssm-session
```
Or specify parameters directly:
```bash
aws-ssm-session -p my-aws-profile -i i-0123456789abcdef
```

### Script Parameters
- `-p <profile>` → Specifies the AWS profile to use.
- `-i <instance_id>` → Specifies the instance ID to connect.

## Example
```bash
user@example: ./aws-ssm-session.sh

---------------------------------------------------------------------
    ___      _____   ___ ___ __  __   ___ ___ ___ ___ ___ ___  _  _
   /_\ \    / / __| / __/ __|  \/  | / __| __/ __/ __|_ _/ _ \| \| |
  / _ \ \/\/ /\__ \ \__ \__ \ |\/| | \__ \ _|\__ \__ \| | (_) | .  |
 /_/ \_\_/\_/ |___/ |___/___/_|  |_| |___/___|___/___\___/___/|_|\_|
                                                        by Gunslito
---------------------------------------------------------------------

==[ Please select your AWS Profile ]====================================================================================
1) aws-cli-profile-1
2) aws-cli-profile-2

Your selection >>> 1

Selected profile: aws-cli-profile-1

⌚ Validating selected profile...

Profile "aws-cli-profile-1" logged successfully.

⌚ Downloading target instance list...

==[ Select the target instance ]========================================================================================
1) instance-1-name              3) instance-3-name              5) instance-5-name             7) instance-7-name
2) instance-2-name              4) instance-4-name              6) instance-6-name             8) instance-8-name

Your selection >>> 2

Selected instance: instance-2-name (i-12345678abcdefghij)

==[ Starting session via Session Manager ]==============================================================================


Starting session with SessionId: user-abcdefghijklmnopqrstuvwxyz.
This session is encrypted using AWS KMS.

user - 0000-00-00 23:59:59
instance-2-name - 10.0.0.1
   ,     #_
   ~\_  ####_        Amazon Linux 2
  ~~  \_#####\
  ~~     \###|       AL2 End of Life is 2025-06-30.
  ~~       \#/ ___
   ~~       V~' '->
    ~~~         /    A newer version of Amazon Linux is available!
      ~~._.   _/
         _/ _/       Amazon Linux 2023, GA and supported until 2028-03-15.
       _/m/'           https://aws.amazon.com/linux/amazon-linux-2023/

Uptime          up 999 weeks, 999 day, 99 hours, 59 minutes
user @ instance-2-name public $ exit
exit


Exiting session with sessionId: user-abcdefghijklmnopqrstuvwxyz.

==[ Session ended ]=====================================================================================================
Command to connect directly to instance-2-name:
/path/to/aws-ssm-session.sh -p aws-cli-profile-1 -i i-12345678abcdefghij
========================================================================================================================
user@example:
```

## License
This project is licensed under the **Creative Commons CC0 1.0 Universal**. See the full license for details.
