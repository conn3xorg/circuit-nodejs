# Local example

Applies circuit-nodejs to a throwaway Rocky Linux 10 container with systemd, installing Node.js 26.13.0 and the `semver` command from npm. You need Conn3x and Podman.

```sh
./up.sh
conn3x init
conn3x apply
conn3x plan
```

The second plan says `No changes.` To see it working:

```sh
ssh -p 2309 -i id_ed25519 -o UserKnownHostsFile=known_hosts root@127.0.0.1 'node -v; semver -r "^1.0.0" 1.2.3'
```

`up.sh` listens on `127.0.0.1:2309`. Set `PORT` to use another port, and pass the same port to Conn3x with `-var port=PORT`. Set `CONTAINERFILE` to test another distro, such as one of the images in Conn3x's `test/images`, which CI uses.

`./down.sh` removes the container, its volumes, the key and the state.
