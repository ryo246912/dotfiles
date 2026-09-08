locals {
  # AgentsViewのregional resourceはすべてLos Angelesへ寄せる。
  region = "us-west2"

  # 変数にしない。この名前は dot_config/agentsview/cloudrun-service.yaml の
  # metadata.name と clrnd.yml の service と一致している必要があり、ここだけ
  # 上書きできると、clrndが作らないserviceへinvoker bindingを付けてしまう。
  # 変更するときは3箇所を同時に変える。
  cloud_run_service_name = "ryo-agentsview"
}
