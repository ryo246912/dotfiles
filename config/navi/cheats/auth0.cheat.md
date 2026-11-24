```sh
% auth0

# fetch AUTH0_ACCESS_TOKEN
export AUTH0_ACCESS_TOKEN=$(curl --request POST --url https://<domain>.us.auth0.com/oauth/token --header 'Content-Type: application/json' --data '{
"client_id":"'"$AUTH0_CLIENT_ID"'",
"client_secret":"'"$AUTH0_CLIENT_SECRET"'",
"audience":"https://<domain>.us.auth0.com/api/v2/",
"grant_type":"client_credentials"
}' | jq -r '.access_token')

# managementAPI : fetch user
curl --request GET \
  --url "https://<domain>.us.auth0.com/api/v2/users/<id>" \
  --header "Authorization: Bearer $AUTH0_ACCESS_TOKEN"

# managementAPI : delete user connection
curl -i -v --request DELETE \
  --url "https://<domain>.us.auth0.com/api/v2/connections/$USER_CONNECTION_ID/users?email=$(jq -Rr @uri <<< '<email>')" \
  --header "Authorization: Bearer $AUTH0_ACCESS_TOKEN"
```

$ xxx: echo xxx
;$
