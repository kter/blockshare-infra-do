# Terraformのインストール方法

```
brew install tfenv
tfenv install
```

# ローカルでの実行

```
export TF_VAR_do_token=(DigitalOceanのトークン)
export AWS_PROFILE=(プロファイル名) terraform apply
# もしくは
export AWS_PROFILE=(プロファイル名) terraform apply -auto-approve
doctl kubernetes cluster kubeconfig save blockshare
```
