```sh
% datastore

# sql : __key__ [ex. SELECT * WHERE __key__ HAS ANCESTOR KEY(XXXProfile, ""own:1340001"")]
SELECT * WHERE __key__ HAS ANCESTOR KEY(<table>, "own:<id>")

# sql : query [ex. SELECT * FROM XXXUser WHERE auth_ids = 'facebook:581272524']
SELECT * FROM <table> WHERE auth_ids = '<id>'
```

$ xxx: echo xxx
;$
