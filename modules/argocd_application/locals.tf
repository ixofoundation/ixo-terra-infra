locals {
  isHelm = var.application.helm != null

  # develop branch → pre-release tags (e.g. v1.2.3-develop.1), main → stable semver (e.g. v1.2.3)
  # mainnet is null — ImageUpdater CRD is skipped entirely for mainnet
  _ws_allow_tags = {
    devnet  = "regexp:-(develop|dev)\\."
    testnet = "regexp:^v?[0-9]+\\.[0-9]+\\.[0-9]+$"
    mainnet = null
  }

  _allow_tags = (
    var.image_updater != null && var.image_updater.allow_tags_override != null
    ? var.image_updater.allow_tags_override
    : lookup(local._ws_allow_tags, terraform.workspace, null)
  )

  image_updater_enabled = (
    var.image_updater != null && var.application.path != null && local._allow_tags != null
  )
}