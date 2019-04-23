# Using an Auth0 OIDC Provider with Vault

## Step 0: Install prerequisites.

You will need Vault 1.1+ and jq in your $PATH.

## Step 1: Create Auth0 account

Go to https://auth0.com and sign up, then verify yourself using the email they'll send you.

You get to choose a domain, I kept their suggested domain dev-9wgh3m41.auth0.com

## Step 2: Configure an Auth0 application

### Record your settings in a file named .env

In the Auth0 browser tab go to

  -> Application -> Default App -> Settings
  
We'll use Default App in this example, but if you're using the one created for
the tester application (see Notes section below) stick with that one, it doesn't 
matter.

Create a file in the same directory as this checkout named `.env`, and populate
it based on the values in the Auth0 Settings configuration tab:

```bash
AUTH0_DOMAIN=your-domain.auth0.com
AUTH0_CLIENT_ID=your-client-id
AUTH0_CLIENT_SECRET=your-secret
```

If you've done the Auth0 tutorial and downloaded the tester application this may
already be done.

### Set callback URLs

Still in 

  -> Application -> Default App -> Settings

modify the field Allowed Callback URLs, adding

```
http://localhost:8200/ui/vault/auth/oidc/oidc/callback,
http://localhost:8250/oidc/callback
```

Hit the `SAVE CHANGES` button.

## Step 3: Run demo-oidc-auth.sh

This will:
- kill any currently running vault
- read your .env file
- spin up a vault server in dev mode
- configure it for your Auth0 OIDC provider using the values in .env
  
## Step 4: Configure Groups in Auth0

We're going to use Auth0 app metadata to provide our grouping behaviour.
There are many ways to do grouping, but this is one of the simplest.

In Auth0: 
- -> Users & Roles -> Users
- Click on your user
- Under Metadata -> app_metadata, modify the json to look like:
```json
    {
      "roles": [
        "admin"
      ]
    }
```

In Auth0:
- -> Rules
- Click `+CREATE YOUR FIRST RULE`
- Choose the `empty rule` template
- Call it "Set user roles", and use this rule definition:
```javascript
function (user, context, callback) {
  user.app_metadata = user.app_metadata || {};
  context.idToken["https://example.com/roles"] = user.app_metadata.roles || [];
  callback(null, user, context);
}
```
- Click `SAVE`

Note that you can't use an Auth0 domain here for the context, not even the one 
they gave you.  For our purposes example.com is fine.

## Step 5: Run demo-oidc-auth-part2.sh

demo-oidc-auth-part2.sh expects to be run after demo-oidc-auth.sh.

It configures a `groups_claim` on the OIDC auth method, and creates a group 
and group alias that link the claim with the group.

### groups_claim

`vault write auth/oidc/role/demo` now has the argument 
`groups_claim="https://example.com/roles"`, which is where our Auth0 rule is storing
the app_metadata roles field inside the JWT id_token coming back from the provider.

### group

The following asks Vault to create an external group with the (arbitrary) name
auth0-admin, and captures the group id for use in the next line.  

Anyone in this group will automatically get the `adm` policy.
  
```bash
gid=$(vault write -format=json identity/group \
    name="auth0-admin" \
    policies="adm" \
    type="external" \
    metadata=organization="Auth0 Users" | jq -r .data.id)
```

### group alias

Finally we ask Vault to create a group alias such that anything coming in 
via the OIDC auth method (based on mount_accessor) will have its groups_claim 
list checked to see if it contains an element `"admin"`; if so, the resulting
token will be associated with auth0-admin's policies, and the user will be
added to the external group.
  
```
vault write identity/group-alias name="admin" \
    mount_accessor=$(vault auth list -format=json  | jq -r '."oidc/".accessor') \
    canonical_id="${gid}"
```


