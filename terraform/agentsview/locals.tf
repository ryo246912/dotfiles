locals {
  # Keep every AgentsView regional resource colocated in Los Angeles.
  region = "us-west2"

  # Not an input variable: the name has to match metadata.name in
  # dot_config/agentsview/cloudrun-service.yaml and service in clrnd.yml, and an
  # override here would only point the invoker binding at a service clrnd never
  # creates. Change all three together or not at all.
  cloud_run_service_name = "ryo-agentsview"
}
