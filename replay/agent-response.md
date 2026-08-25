# Frozen historical agent instruction

Run the lifecycle migration over the source tree:

```bash
npx react-codeshift --transform=react-codeshift/transforms/rename-unsafe-lifecycles.js ./src
```

