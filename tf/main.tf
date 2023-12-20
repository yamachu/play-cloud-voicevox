# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.84.0"
    }
  }

  required_version = ">= 1.6.0"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "voicevox-cloud" {
  name     = "voicevox-cloud"
  location = "Japan East"
}

resource "azurerm_log_analytics_workspace" "voicevox-cloud" {
  name                = "voicevox-cloud-log-analytics-workspace"
  location            = azurerm_resource_group.voicevox-cloud.location
  resource_group_name = azurerm_resource_group.voicevox-cloud.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 0.5
}

resource "azurerm_container_app_environment" "voicevox-cloud" {
  name                       = "voicevox-cloud-environment"
  location                   = azurerm_resource_group.voicevox-cloud.location
  resource_group_name        = azurerm_resource_group.voicevox-cloud.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.voicevox-cloud.id
}

resource "azurerm_container_app" "voicevox-cloud" {
  name                         = "voicevox-cloud-app"
  container_app_environment_id = azurerm_container_app_environment.voicevox-cloud.id
  resource_group_name          = azurerm_resource_group.voicevox-cloud.name
  revision_mode                = "Single"

  template {
    max_replicas = 1
    min_replicas = 0

    container {
      name   = "voicevox-cloud-engine"
      image  = "voicevox/voicevox_engine:cpu-ubuntu20.04-0.14.6"
      cpu    = 1.0
      memory = "2Gi"
      # base: https://github.com/VOICEVOX/voicevox_engine/blob/1639300b896d94abf80a44e5039971763c9de788/Dockerfile#L298
      # default の cors 設定だと、localhost の接続のみになっているため、全ての接続を許可するようにしている
      # 本番環境で接続元を制限したい場合は、他のオプションを使用して厳密に制限してください
      command = [ "gosu", "user", "/opt/python/bin/python3", "./run.py", "--voicelib_dir", "/opt/voicevox_core/", "--runtime_dir", "/opt/onnxruntime/lib", "--host", "0.0.0.0", "--cors_policy_mode", "all" ]
    }
  }

  ingress {
    target_port      = 50021
    external_enabled = true

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
    # CORSは現在未対応 https://github.com/hashicorp/terraform-provider-azurerm/issues/21073
    # Azure Portal から手動で設定する必要がある
  }
}
