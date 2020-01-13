# docker-optimize

## Build the application

```bash
yarn install
```

## Build docker images

```bash
docker build -f Dockerfile -t optimize/docker:1.0 .
docker build -f Dockerfile-V2 -t optimize/docker:2.0 .
```

Check the history of each image

```bash
docker history optimize/docker:1.0
docker history optimize/docker:2.0
```

## Comparing Images

```bash
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
optimize/docker     2.0                 df2dbd6fea46        3 minutes ago       788MB
optimize/docker     1.0                 8a3b428ad343        5 minutes ago       849MB
node                10.16-jessie        a0a3caa753b2        2 weeks ago         685MB
```

The standard docker image for a Debian based distro with node installed is 685MB. The first version of the `Dockerfile` increased the size by 164MB while the second version increased it by 103MB only.

To find out why let us dig a little deeper into each image and view the `docker history`

### optimize/docker:1.0

```plain
IMAGE               CREATED              CREATED BY                                      SIZE
8a3b428ad343        24 seconds ago       /bin/sh -c #(nop)  CMD ["yarn" "start"]         0B
2b37979247cb        25 seconds ago       /bin/sh -c #(nop)  EXPOSE 3000                  0B
4c71529dd91f        25 seconds ago       /bin/sh -c #(nop) WORKDIR /opt/app/myserver     0B
2e96fb231805        26 seconds ago       /bin/sh -c #(nop)  USER myuser                  0B
31838248913e        26 seconds ago       /bin/sh -c chown -R myuser:myuser /opt/app/m…   61.6MB
762f9fac62d3        51 seconds ago       /bin/sh -c #(nop) COPY dir:497d5752dd05bfab3…   61.6MB
9a51026a13df        About a minute ago   /bin/sh -c mkdir -p /opt/app/myserver           0B
fb3cabbff5af        About a minute ago   /bin/sh -c rm -rf /var/lib/apt/lists/* /tmp/…   0B
1e682455c4a6        About a minute ago   /bin/sh -c apt-get clean                        0B
59c9f512f22d        About a minute ago   /bin/sh -c apt-get -y install vim curl unzip    30.8MB
0bf2c05ccdc4        About a minute ago   /bin/sh -c apt-get -y update                    10.1MB
e685787012d6        About a minute ago   /bin/sh -c useradd -m -d /home/myuser -s /bi…   336kB
a0a3caa753b2        2 weeks ago          /bin/sh -c #(nop)  CMD ["node"]                 0B
<missing>           2 weeks ago          /bin/sh -c #(nop)  ENTRYPOINT ["docker-entry…   0B
<missing>           2 weeks ago          /bin/sh -c #(nop) COPY file:238737301d473041…   116B
<missing>           2 weeks ago          /bin/sh -c set -ex   && for key in     6A010…   5.09MB
<missing>           2 weeks ago          /bin/sh -c #(nop)  ENV YARN_VERSION=1.16.0      0B
<missing>           2 weeks ago          /bin/sh -c ARCH= && dpkgArch="$(dpkg --print…   62.7MB
<missing>           2 weeks ago          /bin/sh -c #(nop)  ENV NODE_VERSION=10.16.0     0B
<missing>           2 weeks ago          /bin/sh -c groupadd --gid 1000 node   && use…   335kB
<missing>           4 weeks ago          /bin/sh -c set -ex;  apt-get update;  apt-ge…   323MB
<missing>           4 weeks ago          /bin/sh -c apt-get update && apt-get install…   123MB
<missing>           4 weeks ago          /bin/sh -c set -ex;  if ! command -v gpg > /…   0B
<missing>           4 weeks ago          /bin/sh -c apt-get update && apt-get install…   41.5MB
<missing>           4 weeks ago          /bin/sh -c #(nop)  CMD ["bash"]                 0B
<missing>           4 weeks ago          /bin/sh -c #(nop) ADD file:6f4dbeacd2c7a4894…   129MB
```

The above shows us 3 important points on interest:

1. There are 12 extra layers added to the docker
1. Operations to remove files did not remove anything
1. Chown command duplicated an entire layer

Let us examine these 3 points more closely. The 12 extra layers are exactly the number of docker lines in the `Dockerfile`. So each docker command in the file creates an extra layer, even if the size of that layer is 0B.

The operations we have added to remove files that are not needed did not actually do anything except for creating a new layer. 

```plain
fb3cabbff5af        About a minute ago   /bin/sh -c rm -rf /var/lib/apt/lists/* /tmp/…   0B
1e682455c4a6        About a minute ago   /bin/sh -c apt-get clean                        0B
59c9f512f22d        About a minute ago   /bin/sh -c apt-get -y install vim curl unzip    30.8MB
0bf2c05ccdc4        About a minute ago   /bin/sh -c apt-get -y update                    10.1MB
```

The first 2 commands increased the layer size by 10.1MB and 30.8MB respectively, while the other 2 commands just created a new layer with no size decrease. This new layer just hides the files that are expected to be removed.

The `chown` operation duplicated the entire layer and thus increased the size of the overall image along with changing the ownership of the files. It seems like a normal operation to copy files to the docker and then change the ownership, but it just doubled the size of that layer. Imagine if we copied a 300MB file or set of files totalling 300MB, that would result in a 600MB increase instead of just 300MB.

### optimize/docker:2.0

```plain
IMAGE               CREATED             CREATED BY                                      SIZE                COMMENT
df2dbd6fea46        5 seconds ago       /bin/sh -c #(nop)  CMD ["yarn" "start"]         0B
2182481b9212        6 seconds ago       /bin/sh -c #(nop)  EXPOSE 3000                  0B
d86c0cd5579c        6 seconds ago       /bin/sh -c #(nop) WORKDIR /opt/app/myserver     0B
9af18ff8631d        6 seconds ago       /bin/sh -c #(nop)  USER myuser                  0B
441be23c5d24        7 seconds ago       /bin/sh -c #(nop) COPY --chown=myuser:myuser…   61.6MB
f9b31398deaa        13 seconds ago      /bin/sh -c useradd -m -d /home/myuser -s /bi…   41.2MB
a0a3caa753b2        2 weeks ago         /bin/sh -c #(nop)  CMD ["node"]                 0B
<missing>           2 weeks ago         /bin/sh -c #(nop)  ENTRYPOINT ["docker-entry…   0B
<missing>           2 weeks ago         /bin/sh -c #(nop) COPY file:238737301d473041…   116B
<missing>           2 weeks ago         /bin/sh -c set -ex   && for key in     6A010…   5.09MB
<missing>           2 weeks ago         /bin/sh -c #(nop)  ENV YARN_VERSION=1.16.0      0B
<missing>           2 weeks ago         /bin/sh -c ARCH= && dpkgArch="$(dpkg --print…   62.7MB
<missing>           2 weeks ago         /bin/sh -c #(nop)  ENV NODE_VERSION=10.16.0     0B
<missing>           2 weeks ago         /bin/sh -c groupadd --gid 1000 node   && use…   335kB
<missing>           4 weeks ago         /bin/sh -c set -ex;  apt-get update;  apt-ge…   323MB
<missing>           4 weeks ago         /bin/sh -c apt-get update && apt-get install…   123MB
<missing>           4 weeks ago         /bin/sh -c set -ex;  if ! command -v gpg > /…   0B
<missing>           4 weeks ago         /bin/sh -c apt-get update && apt-get install…   41.5MB
<missing>           4 weeks ago         /bin/sh -c #(nop)  CMD ["bash"]                 0B
<missing>           4 weeks ago         /bin/sh -c #(nop) ADD file:6f4dbeacd2c7a4894…   129MB
```

The above is an optimized version of the initial `Dockerfile` and as can be seen there are only 7 extra layers instead of 12. Now knowing that every command in a `Dockerfile` will result in a new layer we consolidated all linux commands in 1 `RUN` statement. We also do not bother to remove files since they do not get removed anyways. And we use Docker's [Copy-on-Write (CoW) strategy](https://docs.docker.com/v17.09/engine/userguide/storagedriver/imagesandcontainers/#the-copy-on-write-cow-strategy) by copying the files and changing their ownership on the fly. This is done using the `COPY --chown=myuser:myuser` [command](https://docs.docker.com/engine/reference/builder/#copy). We can plainly see that for that command only a 1 new layer was created which cost 61.6MB. The previuos version duplicated that layer to be 123.2MB. And yes, the `copy --chown:` command changes the ownership of all files, folders and sub-folders.

## References

[https://blog.mornati.net/docker-images-and-chown/](https://blog.mornati.net/docker-images-and-chown/)
[https://docs.docker.com/v17.09/engine/userguide/storagedriver/imagesandcontainers/](https://docs.docker.com/v17.09/engine/userguide/storagedriver/imagesandcontainers/)
