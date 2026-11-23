resource "azurerm_policy_definition" "deny_ssh" {
  name         = "deny-public-ssh"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Deny SSH exposed to Internet"

  description = "Denies NSG rules that allow inbound SSH from Internet."

  policy_rule = jsonencode({
    "if" = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Network/networkSecurityGroups/securityRules"
        },
        {
          field  = "Microsoft.Network/networkSecurityGroups/securityRules/access"
          equals = "Allow"
        },
        {
          field  = "Microsoft.Network/networkSecurityGroups/securityRules/direction"
          equals = "Inbound"
        },
        {
          field  = "Microsoft.Network/networkSecurityGroups/securityRules/destinationPortRange"
          equals = "22"
        },
        {
          anyOf = [
            {
              field  = "Microsoft.Network/networkSecurityGroups/securityRules/sourceAddressPrefix"
              equals = "*"
            },
            {
              field  = "Microsoft.Network/networkSecurityGroups/securityRules/sourceAddressPrefix"
              equals = "Internet"
            }
          ]
        }
      ]
    }

    "then" = {
      effect = "Deny"
    }
  })
}

resource "azurerm_resource_group_policy_assignment" "deny_ssh" {
  name                 = "deny-public-ssh"
  resource_group_id    = azurerm_resource_group.main.id
  policy_definition_id = azurerm_policy_definition.deny_ssh.id
}
