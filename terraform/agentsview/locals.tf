locals {
  # AgentsViewのregional resourceはすべてLos Angelesへ寄せる。
  region = "us-west2"

  # 変数にしない。この名前は dot_config/agentsview/cloudrun-service.yaml の
  # metadata.name と clrnd.yml の service と一致している必要があり、ここだけ
  # 上書きできると、clrndが作らないserviceへinvoker bindingを付けてしまう。
  # 変更するときは3箇所を同時に変える。
  cloud_run_service_name = "ryo-agentsview"

  # Cloud Runのdeterministic URL。Cloud Runはserviceへ2種類のURLを割り当てる。
  # 一つはhash入りのnon-deterministic URL、もう一つがこの
  # https://<service>-<project number>.<region>.run.app である。後者はservice名・
  # project number・regionだけで決まるため、serviceを作る前から確定していて、
  # deleteして作り直しても同じ値に戻る。
  #
  # AgentsViewのconfig.tomlはpublic_urlを必要とし、これがhash入りURLだと
  # 「serviceを作る→URLを調べる→configを書く→再deploy」という順序が要る。
  # deterministic URLならその往復が消えるので、public_urlはこちらへ固定する。
  #
  # DNS segment（service名 + "-" + project number）が63文字以内のときだけ割り当て
  # られる。ryo-agentsview（14）+ 1 + project number（12前後）で余裕がある。
  cloud_run_url = "https://${local.cloud_run_service_name}-${data.google_project.current.number}.${local.region}.run.app"
}
