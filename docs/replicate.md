# Replicating to atom.iriscouch.com

```sh
curl -H "Content-Type: application/json" -d '{"source": "http://isaacs.iriscouch.com/registry", "target": "registry", "continuous": true, "create_target": true, "user_ctx": {"roles": ["_admin"]}}' https://atom.iriscouch.com/_replicator -u hubot
```
