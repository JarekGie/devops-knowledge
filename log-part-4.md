```text
[Pipeline] stage
[Pipeline] { (Build and push docker)
[Pipeline] container
[Pipeline] {
[Pipeline] sshagent
[ssh-agent] Using credentials root (mlb-dockerhost-ssh)
Executing sh script inside container trivy of pod ass-plan-odkupow-fe-plan-odkupow-uat-147-7zd33-ctpt5-r7z3w
Executing command: "ssh-agent" 
exit
SSH_AUTH_SOCK=/root/.ssh/agent/s.HVDBZygv8s.agent.qIFxGwTnoq; export SSH_AUTH_SOCK;
SSH_AGENT_PID=15; export SSH_AGENT_PID;
echo Agent pid 15;
SSH_AUTH_SOCK=/root/.ssh/agent/s.HVDBZygv8s.agent.qIFxGwTnoq
SSH_AGENT_PID=15
Running ssh-add (command line suppressed)
Identity added: /home/jenkins/agent/workspace/ASS/plan-odkupow/FE/plan-odkupow-uat@tmp/private_key_14611636073098350686.key (mlb-dockerhost)
[ssh-agent] Started.
[Pipeline] {
[Pipeline] withCredentials
Masking supported pattern matches of $plano_jenkins_aws_credentials
[Pipeline] {
[Pipeline] echo
⬤ BUILD IMAGE AND PUSH TO REPOSITORY
[Pipeline] script
[Pipeline] {
[Pipeline] withCredentials
Masking supported pattern matches of $cred
[Pipeline] {
[Pipeline] script
[Pipeline] {
[Pipeline] echo
login to: 333320664022.dkr.ecr.eu-central-1.amazonaws.com
[Pipeline] sh
+ echo 333320664022.dkr.ecr.eu-central-1.amazonaws.com
+ awk '-F[.]' '{print $4}'
[Pipeline] sh
Warning: A secret was passed to "sh" using Groovy String interpolation, which is insecure.
		 Affected argument(s) used the following variable(s): [cred]
		 See https://jenkins.io/redirect/groovy-string-interpolation for details.
+ mkdir -p /root/.aws
+ cp **** /root/.aws/credentials
+ aws ecr get-login-password --region eu-central-1
+ docker login --username AWS --password-stdin 333320664022.dkr.ecr.eu-central-1.amazonaws.com

WARNING! Your credentials are stored unencrypted in '/root/.docker/config.json'.
Configure a credential helper to remove this warning. See
https://docs.docker.com/go/credential-store/

Login Succeeded
[Pipeline] }
[Pipeline] // script
[Pipeline] }
[Pipeline] // withCredentials
[Pipeline] findFiles
[Pipeline] echo
--- SEARCH RESULTS ---
[Pipeline] echo
plan-odkupow-cicd/dockerfiles/FE/react.dockerfile
[Pipeline] echo
----------------------
[Pipeline] echo
--- SELECTED DOCKERFILE ---
[Pipeline] echo
plan-odkupow-cicd/dockerfiles/FE/react.dockerfile
[Pipeline] echo
---------------------------
[Pipeline] echo
imageName: planodkupow-uat:front.147
[Pipeline] echo
Dockerfile: react.dockerfile
[Pipeline] echo
context: .
[Pipeline] echo
Argument: ENVI=dev
[Pipeline] sh
+ jq -r '.auths | keys[0]' /root/.docker/config.json
[Pipeline] echo
Running: docker build --rm --no-cache -t 333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-uat:front.147 --build-arg ENVI=dev -f plan-odkupow-cicd/dockerfiles/FE/react.dockerfile .
[Pipeline] echo
check Dockerfile syntax
[Pipeline] sh
+ find . -name react.dockerfile -print -quit
[Pipeline] echo
dockerfile path:./plan-odkupow-cicd/dockerfiles/FE/react.dockerfile

[Pipeline] echo
The file has the .dockerfile extension.
[Pipeline] sh
+ mkdir -p trivy_temp
+ mkdir -p trivy-reports
+ find . -type f -name react.dockerfile -exec cp '{}' ./trivy_temp/react.dockerfile ';'
cp: './trivy_temp/react.dockerfile' and './trivy_temp/react.dockerfile' are the same file
+ ls -l trivy_temp
total 4
-rw-r--r--    1 root     root           230 Apr 20 09:42 react.dockerfile
+ trivy config --severity HIGH,CRITICAL --exit-code 0 --misconfig-scanners dockerfile --format template --template @/contrib/html.tpl -o trivy-reports/dockerfile_planodkupow-uat:front.147.html ./trivy_temp/react.dockerfile
2026-04-20T09:42:43Z	INFO	[misconfig] Misconfiguration scanning is enabled
2026-04-20T09:42:43Z	INFO	[checks-client] Using existing checks from cache	path="/root/.cache/trivy/policy/content"
2026-04-20T09:42:49Z	INFO	Detected config files	num=1

📣 Notices:
  - Version 0.70.0 of Trivy is now available, current version is 0.69.1

To suppress version checks, run Trivy scans with the --skip-version-check flag

[Pipeline] echo
build docker images
[Pipeline] withSonarQubeEnv
Injecting SonarQube environment variables using the configuration: sonarqube
[Pipeline] {
[Pipeline] sh
+ docker build --rm --no-cache -t 333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-uat:front.147 --build-arg 'ENVI=dev' -f plan-odkupow-cicd/dockerfiles/FE/react.dockerfile .
DEPRECATED: The legacy builder is deprecated and will be removed in a future release.
            Install the buildx component to build images with BuildKit:
            https://docs.docker.com/go/buildx/

Sending build context to Docker daemon  807.4MB

Step 1/6 : FROM nginx:1.27.2-alpine
 ---> a5967740120f
Step 2/6 : RUN mkdir -p /usr/share/nginx/html
 ---> Running in 2bc1a1c1b92a
 ---> Removed intermediate container 2bc1a1c1b92a
 ---> c788f0f02cbc
Step 3/6 : COPY ./dist /usr/share/nginx/html
 ---> d5258a05b0db
Step 4/6 : COPY ./plan-odkupow-cicd/dockerfiles/FE/nginx.conf /etc/nginx/conf.d/default.conf
 ---> 00906ccd98af
Step 5/6 : ENV VIRTUAL_HOST=whoami.localhost
 ---> Running in 21949354a3c5
 ---> Removed intermediate container 21949354a3c5
 ---> aac9f2a8c86a
Step 6/6 : ENV VIRTUAL_PORT=80
 ---> Running in 30bf6c4df8ac
 ---> Removed intermediate container 30bf6c4df8ac
 ---> d7e97f277d03
[Warning] One or more build-args [ENVI] were not consumed
Successfully built d7e97f277d03
Successfully tagged 333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-uat:front.147
[Pipeline] }
WARN: Unable to locate 'report-task.txt' in the workspace. Did the SonarScanner succeed?
[Pipeline] // withSonarQubeEnv
[Pipeline] echo
trivy scan vulnerabilities
[Pipeline] sh
+ trivy image --skip-db-update --skip-java-db-update --format template --template @/contrib/html.tpl -o trivy-reports/image_planodkupow-uat:front.147.html --severity HIGH,CRITICAL --exit-code 0 --ignore-unfixed --exit-on-eol 0 333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-uat:front.147
2026-04-20T09:45:16Z	INFO	[vuln] Vulnerability scanning is enabled
2026-04-20T09:45:16Z	INFO	[secret] Secret scanning is enabled
2026-04-20T09:45:16Z	INFO	[secret] If your scanning is slow, please try '--scanners vuln' to disable secret scanning
2026-04-20T09:45:16Z	INFO	[secret] Please see https://trivy.dev/docs/v0.69/guide/scanner/secret#recommendation for faster secret detection
2026-04-20T09:45:21Z	INFO	Detected OS	family="alpine" version="3.20.3"
2026-04-20T09:45:21Z	INFO	[alpine] Detecting vulnerabilities...	os_version="3.20" repository="3.20" pkg_num=66
2026-04-20T09:45:21Z	INFO	Number of language-specific files	num=0
2026-04-20T09:45:21Z	WARN	Using severities from other vendors for some vulnerabilities. Read https://trivy.dev/docs/v0.69/guide/scanner/vulnerability#severity-selection for details.
2026-04-20T09:45:21Z	WARN	This OS version is no longer supported by the distribution	family="alpine" version="3.20.3"
2026-04-20T09:45:21Z	WARN	The vulnerability detection may be insufficient because security updates are not provided

📣 Notices:
  - Version 0.70.0 of Trivy is now available, current version is 0.69.1

To suppress version checks, run Trivy scans with the --skip-version-check flag

[Pipeline] echo
publishing TRIVY REPORT TO JENKINS PROJECT
[Pipeline] publishHTML
[htmlpublisher] Archiving HTML reports...
[htmlpublisher] Archiving at BUILD level /home/jenkins/agent/workspace/ASS/plan-odkupow/FE/plan-odkupow-uat/trivy-reports to Trivy_20147_20planodkupow-uat_3afront_2e147
[htmlpublisher] Copying recursive using current thread
[Pipeline] sh
+ docker push 333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-uat:front.147
The push refers to repository [333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-uat]
159997e196dd: Preparing
fabd01da166a: Preparing
b67a2e28b4c8: Preparing
1ce97418c44e: Preparing
8d94d71d4b48: Preparing
19d3bde9037c: Preparing
3ca5de8f08eb: Preparing
ffe4285e2906: Preparing
df75bb36e265: Preparing
75654b8eeebd: Preparing
df75bb36e265: Waiting
75654b8eeebd: Waiting
19d3bde9037c: Waiting
3ca5de8f08eb: Waiting
ffe4285e2906: Waiting
1ce97418c44e: Layer already exists
b67a2e28b4c8: Layer already exists
8d94d71d4b48: Layer already exists
19d3bde9037c: Layer already exists
3ca5de8f08eb: Layer already exists
ffe4285e2906: Layer already exists
df75bb36e265: Layer already exists
75654b8eeebd: Layer already exists
159997e196dd: Pushed
fabd01da166a: Pushed
front.147: digest: sha256:510cc39ec8b79f54b72cf66883034eea645d3c276b695a1cbe89e52ae2c69730 size: 2407
+ docker rmi 333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-uat:front.147
Untagged: 333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-uat:front.147
Untagged: 333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-uat@sha256:510cc39ec8b79f54b72cf66883034eea645d3c276b695a1cbe89e52ae2c69730
Deleted: sha256:d7e97f277d0394d3b336ec0a0d10c92084a037de8a8f375ab33831af143aa6f5
Deleted: sha256:aac9f2a8c86a4c2a0d08636f9a0838f5f7a606f641165468db55165ba0143b23
Deleted: sha256:00906ccd98af04ce5029b2b73db658115f8c796ab2c91ab54c9e876a9bf242d2
Deleted: sha256:621d240935cf822a6762a81fb845014d626be25437bf157cfd6ded6dc1bb03d1
Deleted: sha256:d5258a05b0dbd472d751c98264d951788e313ee9e7d9168b3ada84b63165987f
Deleted: sha256:4ae710857e0bb7a43b0171f8d55396f608a1eb7b9103b05fc61cf1334cdf7dcd
Deleted: sha256:c788f0f02cbc0a53a783237153c7d813780eb6f6db2e70748c6a0c545b2397c8
[Pipeline] }
[Pipeline] // script
[Pipeline] }
[Pipeline] // withCredentials
[Pipeline] }
Executing sh script inside container trivy of pod ass-plan-odkupow-fe-plan-odkupow-uat-147-7zd33-ctpt5-r7z3w
Executing command: "ssh-agent" "-k" 
exit
unset SSH_AUTH_SOCK;
unset SSH_AGENT_PID;
echo Agent pid 15 killed;
[ssh-agent] Stopped.
[Pipeline] // sshagent
[Pipeline] }
[Pipeline] // container
[Pipeline] }
[Pipeline] // stage
[Pipeline] stage
[Pipeline] { (Deploy AWS)
[Pipeline] script
[Pipeline] {
[Pipeline] echo
⬤ Deploy AWS
[Pipeline] lock
Trying to acquire lock on [Resource: plan_odkupow_update_stack_uat]
The resource [plan_odkupow_update_stack_uat] is locked by build ASS » plan-odkupow » BE » plan-odkupow-uat-prod #322 uat #322 uat since Apr 20, 2026, 11:16 AM.
[Resource: plan_odkupow_update_stack_uat] is not free, waiting for execution ...
[Required resources: [plan_odkupow_update_stack_uat]] added into queue at position 0
Lock acquired on [Resource: plan_odkupow_update_stack_uat]
[Pipeline] {
[Pipeline] container
[Pipeline] {
[Pipeline] withCredentials
Masking supported pattern matches of $plano_jenkins_aws_credentials
[Pipeline] {
[Pipeline] sh
Warning: A secret was passed to "sh" using Groovy String interpolation, which is insecure.
		 Affected argument(s) used the following variable(s): [plano_jenkins_aws_credentials]
		 See https://jenkins.io/redirect/groovy-string-interpolation for details.
+ mkdir -p /root/.aws
+ cp **** /root/.aws/credentials
+ aws ecr get-login-password --region eu-central-1
[Pipeline] }
[Pipeline] // withCredentials
[Pipeline] sh
+++ aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query 'Stacks[].Parameters[].ParameterKey' --output text
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' DBMasterUser = FrontImg ']'
++ printf 'ParameterKey=DBMasterUser,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' CertyfikatPro = FrontImg ']'
++ printf 'ParameterKey=CertyfikatPro,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' Srodowisko = FrontImg ']'
++ printf 'ParameterKey=Srodowisko,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' DBInstanceType = FrontImg ']'
++ printf 'ParameterKey=DBInstanceType,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' TaskSACpu = FrontImg ']'
++ printf 'ParameterKey=TaskSACpu,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' DownscaleCount = FrontImg ']'
++ printf 'ParameterKey=DownscaleCount,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' UpscaleCpu = FrontImg ']'
++ printf 'ParameterKey=UpscaleCpu,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' TaskVehicleCpu = FrontImg ']'
++ printf 'ParameterKey=TaskVehicleCpu,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' TaskMemory = FrontImg ']'
++ printf 'ParameterKey=TaskMemory,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' HealthyThresholdCount = FrontImg ']'
++ printf 'ParameterKey=HealthyThresholdCount,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' Stickiness = FrontImg ']'
++ printf 'ParameterKey=Stickiness,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' UpscaleCooldown = FrontImg ']'
++ printf 'ParameterKey=UpscaleCooldown,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' HealthCheckIntervalSeconds = FrontImg ']'
++ printf 'ParameterKey=HealthCheckIntervalSeconds,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' InsuranceImg = FrontImg ']'
++ printf 'ParameterKey=InsuranceImg,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' PHPmemLimit = FrontImg ']'
++ printf 'ParameterKey=PHPmemLimit,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' UpscaleAggType = FrontImg ']'
++ printf 'ParameterKey=UpscaleAggType,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' UnhealthyThresholdCount = FrontImg ']'
++ printf 'ParameterKey=UnhealthyThresholdCount,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' ReportImg = FrontImg ']'
++ printf 'ParameterKey=ReportImg,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' Domena = FrontImg ']'
++ printf 'ParameterKey=Domena,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' VehicleImg = FrontImg ']'
++ printf 'ParameterKey=VehicleImg,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' StorageImg = FrontImg ']'
++ printf 'ParameterKey=StorageImg,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' GatewayImg = FrontImg ']'
++ printf 'ParameterKey=GatewayImg,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' Projekt = FrontImg ']'
++ printf 'ParameterKey=Projekt,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' DomenaPro = FrontImg ']'
++ printf 'ParameterKey=DomenaPro,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' FrontImg = FrontImg ']'
++ printf 'ParameterKey=FrontImg,ParameterValue=333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-uat:front.147 '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' TaskSAMemory = FrontImg ']'
++ printf 'ParameterKey=TaskSAMemory,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' Certyfikat = FrontImg ']'
++ printf 'ParameterKey=Certyfikat,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' DBStorage = FrontImg ']'
++ printf 'ParameterKey=DBStorage,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' UpscaleStat = FrontImg ']'
++ printf 'ParameterKey=UpscaleStat,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' NginxMemLimit = FrontImg ']'
++ printf 'ParameterKey=NginxMemLimit,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' DomenaForeign = FrontImg ']'
++ printf 'ParameterKey=DomenaForeign,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' HealthCheckPath = FrontImg ']'
++ printf 'ParameterKey=HealthCheckPath,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' DBPort = FrontImg ']'
++ printf 'ParameterKey=DBPort,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' HealthCheckTimeoutSeconds = FrontImg ']'
++ printf 'ParameterKey=HealthCheckTimeoutSeconds,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' UpscaleCount = FrontImg ']'
++ printf 'ParameterKey=UpscaleCount,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' RegistrationImg = FrontImg ']'
++ printf 'ParameterKey=RegistrationImg,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' FinanceImg = FrontImg ']'
++ printf 'ParameterKey=FinanceImg,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' DeregistrationDelay = FrontImg ']'
++ printf 'ParameterKey=DeregistrationDelay,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' SecToken = FrontImg ']'
++ printf 'ParameterKey=SecToken,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' TaskCPU = FrontImg ']'
++ printf 'ParameterKey=TaskCPU,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' MessageImg = FrontImg ']'
++ printf 'ParameterKey=MessageImg,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' TaskDesiredCount = FrontImg ']'
++ printf 'ParameterKey=TaskDesiredCount,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' DBMasterPass = FrontImg ']'
++ printf 'ParameterKey=DBMasterPass,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' HealthCheckGracePeriodSeconds = FrontImg ']'
++ printf 'ParameterKey=HealthCheckGracePeriodSeconds,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' DownscaleAggType = FrontImg ']'
++ printf 'ParameterKey=DownscaleAggType,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' InteropImg = FrontImg ']'
++ printf 'ParameterKey=InteropImg,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' ExpertiseImg = FrontImg ']'
++ printf 'ParameterKey=ExpertiseImg,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' OfferImg = FrontImg ']'
++ printf 'ParameterKey=OfferImg,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' ECSServiceAutoScalingRoleARN = FrontImg ']'
++ printf 'ParameterKey=ECSServiceAutoScalingRoleARN,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' ALBIdleTimeout = FrontImg ']'
++ printf 'ParameterKey=ALBIdleTimeout,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' TaskVehicleMemory = FrontImg ']'
++ printf 'ParameterKey=TaskVehicleMemory,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' AuthImg = FrontImg ']'
++ printf 'ParameterKey=AuthImg,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' DownscalePeriod = FrontImg ']'
++ printf 'ParameterKey=DownscalePeriod,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' DownscaleStep = FrontImg ']'
++ printf 'ParameterKey=DownscaleStep,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' UpscalePeriod = FrontImg ']'
++ printf 'ParameterKey=UpscalePeriod,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' CertyfikatForeign = FrontImg ']'
++ printf 'ParameterKey=CertyfikatForeign,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' UpscaleStep = FrontImg ']'
++ printf 'ParameterKey=UpscaleStep,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' DownscaleCpu = FrontImg ']'
++ printf 'ParameterKey=DownscaleCpu,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' DownscaleCooldown = FrontImg ']'
++ printf 'ParameterKey=DownscaleCooldown,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' TaskMaxCount = FrontImg ']'
++ printf 'ParameterKey=TaskMaxCount,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' InspectionImg = FrontImg ']'
++ printf 'ParameterKey=InspectionImg,UsePreviousValue=true '
++ for paramval in '$(aws cloudformation describe-stacks --region eu-central-1 --stack-name planodkupow-uat --query "Stacks[].Parameters[].ParameterKey" --output text)'
++ '[' DownscaleStat = FrontImg ']'
++ printf 'ParameterKey=DownscaleStat,UsePreviousValue=true '
+ aws cloudformation update-stack --region eu-central-1 --stack-name planodkupow-uat --use-previous-template --parameters ParameterKey=DBMasterUser,UsePreviousValue=true ParameterKey=CertyfikatPro,UsePreviousValue=true ParameterKey=Srodowisko,UsePreviousValue=true ParameterKey=DBInstanceType,UsePreviousValue=true ParameterKey=TaskSACpu,UsePreviousValue=true ParameterKey=DownscaleCount,UsePreviousValue=true ParameterKey=UpscaleCpu,UsePreviousValue=true ParameterKey=TaskVehicleCpu,UsePreviousValue=true ParameterKey=TaskMemory,UsePreviousValue=true ParameterKey=HealthyThresholdCount,UsePreviousValue=true ParameterKey=Stickiness,UsePreviousValue=true ParameterKey=UpscaleCooldown,UsePreviousValue=true ParameterKey=HealthCheckIntervalSeconds,UsePreviousValue=true ParameterKey=InsuranceImg,UsePreviousValue=true ParameterKey=PHPmemLimit,UsePreviousValue=true ParameterKey=UpscaleAggType,UsePreviousValue=true ParameterKey=UnhealthyThresholdCount,UsePreviousValue=true ParameterKey=ReportImg,UsePreviousValue=true ParameterKey=Domena,UsePreviousValue=true ParameterKey=VehicleImg,UsePreviousValue=true ParameterKey=StorageImg,UsePreviousValue=true ParameterKey=GatewayImg,UsePreviousValue=true ParameterKey=Projekt,UsePreviousValue=true ParameterKey=DomenaPro,UsePreviousValue=true ParameterKey=FrontImg,ParameterValue=333320664022.dkr.ecr.eu-central-1.amazonaws.com/planodkupow-uat:front.147 ParameterKey=TaskSAMemory,UsePreviousValue=true ParameterKey=Certyfikat,UsePreviousValue=true ParameterKey=DBStorage,UsePreviousValue=true ParameterKey=UpscaleStat,UsePreviousValue=true ParameterKey=NginxMemLimit,UsePreviousValue=true ParameterKey=DomenaForeign,UsePreviousValue=true ParameterKey=HealthCheckPath,UsePreviousValue=true ParameterKey=DBPort,UsePreviousValue=true ParameterKey=HealthCheckTimeoutSeconds,UsePreviousValue=true ParameterKey=UpscaleCount,UsePreviousValue=true ParameterKey=RegistrationImg,UsePreviousValue=true ParameterKey=FinanceImg,UsePreviousValue=true ParameterKey=DeregistrationDelay,UsePreviousValue=true ParameterKey=SecToken,UsePreviousValue=true ParameterKey=TaskCPU,UsePreviousValue=true ParameterKey=MessageImg,UsePreviousValue=true ParameterKey=TaskDesiredCount,UsePreviousValue=true ParameterKey=DBMasterPass,UsePreviousValue=true ParameterKey=HealthCheckGracePeriodSeconds,UsePreviousValue=true ParameterKey=DownscaleAggType,UsePreviousValue=true ParameterKey=InteropImg,UsePreviousValue=true ParameterKey=ExpertiseImg,UsePreviousValue=true ParameterKey=OfferImg,UsePreviousValue=true ParameterKey=ECSServiceAutoScalingRoleARN,UsePreviousValue=true ParameterKey=ALBIdleTimeout,UsePreviousValue=true ParameterKey=TaskVehicleMemory,UsePreviousValue=true ParameterKey=AuthImg,UsePreviousValue=true ParameterKey=DownscalePeriod,UsePreviousValue=true ParameterKey=DownscaleStep,UsePreviousValue=true ParameterKey=UpscalePeriod,UsePreviousValue=true ParameterKey=CertyfikatForeign,UsePreviousValue=true ParameterKey=UpscaleStep,UsePreviousValue=true ParameterKey=DownscaleCpu,UsePreviousValue=true ParameterKey=DownscaleCooldown,UsePreviousValue=true ParameterKey=TaskMaxCount,UsePreviousValue=true ParameterKey=InspectionImg,UsePreviousValue=true ParameterKey=DownscaleStat,UsePreviousValue=true

An error occurred (ValidationError) when calling the UpdateStack operation: Stack:arn:aws:cloudformation:eu-central-1:333320664022:stack/planodkupow-uat/1a5c1070-fa9e-11eb-9874-0223c5fa1c6c is in UPDATE_ROLLBACK_FAILED state and can not be updated.
[Pipeline] }
[Pipeline] // container
[Pipeline] }
Lock released on resource [Resource: plan_odkupow_update_stack_uat]
[Pipeline] // lock
[Pipeline] }
[Pipeline] // script
[Pipeline] }
[Pipeline] // stage
[Pipeline] }
[Pipeline] // withEnv
[Pipeline] }
[Pipeline] // withEnv
[Pipeline] }
[Pipeline] // node
[Pipeline] }
[Pipeline] // podTemplate
[Pipeline] End of Pipeline
ERROR: script returned exit code 254
Finished: FAILURE
```
