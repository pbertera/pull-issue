For similicity we create an image with a single layer.

We create 3 images with 3 tags and we move the `latest` tag around the 3 images

```
$ podman login quay.io
```

```
$ podman images
REPOSITORY  TAG         IMAGE ID    CREATED     SIZE
```

Build and push of `quay.io/pbertera/pull-test:v1`

```
$ podman build -f 1.Containerfile -t quay.io/pbertera/pull-test:v1 .
[1/2] STEP 1/4: FROM docker.io/library/golang:1.24
Trying to pull docker.io/library/golang:1.24...

[...]

[2/2] COMMIT quay.io/pbertera/pull-test:v1
--> 63010fd24df2
Successfully tagged quay.io/pbertera/pull-test:v1
63010fd24df21a4f33aef8c5530b1e8fb56f966d45dbd83eec78131a0b6a0289

$ podman push quay.io/pbertera/pull-test:v1
Getting image source signatures
Copying blob a9845d99238d done   | 
Copying config 63010fd24d done   | 
Writing manifest to image destination
```

Build and push of `quay.io/pbertera/pull-test:v2`

```
$ podman build -f 2.Containerfile -t quay.io/pbertera/pull-test:v2 .
[1/2] STEP 1/4: FROM docker.io/library/golang:1.24

[...]

[2/2] COMMIT quay.io/pbertera/pull-test:v2
--> 2a091e613448
Successfully tagged quay.io/pbertera/pull-test:v2
2a091e613448e2d682ce181e1301aa0dcfbf1a7f2f8e326a5842e52a6deb6686

$ podman push quay.io/pbertera/pull-test:v2
Getting image source signatures
Copying blob 4a134efc996f done   | 
Copying config 2a091e6134 done   | 
Writing manifest to image destination
```

Build and push of `quay.io/pbertera/pull-test:v3`

```
 podman build -f 3.Containerfile -t quay.io/pbertera/pull-test:v3 .
[1/2] STEP 1/4: FROM docker.io/library/golang:1.24

[...]

[2/2] COMMIT quay.io/pbertera/pull-test:v3
--> 360c2b517e47
Successfully tagged quay.io/pbertera/pull-test:v3
360c2b517e4715620d56d0ca869834185b5c1015250b697c11b7ef37471d4426

$ podman push quay.io/pbertera/pull-test:v3
Getting image source signatures
Copying blob 5d205a47e737 done   | 
Copying config 360c2b517e done   | 
Writing manifest to image destination
```

Get the digest and layers of each image:

```
$ for ver in $(seq 1 3); do echo "IMAGE: quay.io/pbertera/pull-test:v${ver}"; skopeo inspect docker://quay.io/pbertera/pull-test:v1 | jq -r '.Digest,.Layers'; echo; done
IMAGE: quay.io/pbertera/pull-test:v1
sha256:1e3db69c86ebade790816eaeab6ea6e14c41e74cabd19b5fc4fa886f99c77cc1
[
  "sha256:eb4eb074075889c5f12a67c272b36b896fba3fceacb264bdcc3d5dce6130ceba"
]

IMAGE: quay.io/pbertera/pull-test:v2
sha256:1e3db69c86ebade790816eaeab6ea6e14c41e74cabd19b5fc4fa886f99c77cc1
[
  "sha256:eb4eb074075889c5f12a67c272b36b896fba3fceacb264bdcc3d5dce6130ceba"
]

IMAGE: quay.io/pbertera/pull-test:v3
sha256:1e3db69c86ebade790816eaeab6ea6e14c41e74cabd19b5fc4fa886f99c77cc1
[
  "sha256:eb4eb074075889c5f12a67c272b36b896fba3fceacb264bdcc3d5dce6130ceba"
]
```

Let's tag the `v1` as `latest`

```
$ podman tag quay.io/pbertera/pull-test:v1 quay.io/pbertera/pull-test:latest
$ podman push quay.io/pbertera/pull-test:latest
Getting image source signatures
Copying blob eb4eb0740758 skipped: already exists  
Copying config 63010fd24d done   | 
Writing manifest to image destination
```

The `latest` tag has a different digest but contains the same layer of `v1`:

```
$ skopeo inspect docker://quay.io/pbertera/pull-test:latest 
{
    "Name": "quay.io/pbertera/pull-test",
    "Digest": "sha256:1e3db69c86ebade790816eaeab6ea6e14c41e74cabd19b5fc4fa886f99c77cc1",
    "RepoTags": [
        "latest",
        "v1",
        "v2",
        "v3"
    ],
    "Created": "2025-06-20T12:54:11.206134895Z",
    "DockerVersion": "",
    "Labels": {
        "io.buildah.version": "1.33.8"
    },
    "Architecture": "amd64",
    "Os": "linux",
    "Layers": [
        "sha256:eb4eb074075889c5f12a67c272b36b896fba3fceacb264bdcc3d5dce6130ceba"
    ],
    "LayersData": [
        {
            "MIMEType": "application/vnd.oci.image.layer.v1.tar+gzip",
            "Digest": "sha256:eb4eb074075889c5f12a67c272b36b896fba3fceacb264bdcc3d5dce6130ceba",
            "Size": 1368780,
            "Annotations": null
        }
    ],
    "Env": [
        "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
        "VERSION=1"
    ]
```

Let's create the depolyment (setup the `NODE` variable)

```
$ cat deploy.yml | NODE=ip-10-0-0-191.us-east-2.compute.internal  envsubst | oc apply -f -
$ oc get deploy,pods 
NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/pull-test   1/1     1            1           95s

NAME                             READY   STATUS    RESTARTS   AGE
pod/pull-test-69c77fccbf-rzppq   1/1     Running   0          95s

$ oc logs deployments/pull-test 
VERSION:  1
```

Check the image running on the node: the digest is the same of `quay.io/pbertera/pull-test:latest`

```
$ oc debug node/ip-10-0-0-191.us-east-2.compute.internal -- chroot /host crictl inspecti quay.io/pbertera/pull-test:latest | jq -r .status.repoDigests
[
  "quay.io/pbertera/pull-test@sha256:1e3db69c86ebade790816eaeab6ea6e14c41e74cabd19b5fc4fa886f99c77cc1"
]
```

Now let's tag the `v2` as `latest` and remove the `v1`

```
$ podman tag quay.io/pbertera/pull-test:v2 quay.io/pbertera/pull-test:latest
$ podman images
REPOSITORY                  TAG         IMAGE ID      CREATED      SIZE
<none>                      <none>      eed2e1c24c11  3 hours ago  1.08 kB
quay.io/pbertera/pull-test  v3          360c2b517e47  3 hours ago  2.22 MB
<none>                      <none>      4dfc0134d159  3 hours ago  1.08 kB
quay.io/pbertera/pull-test  latest      2a091e613448  3 hours ago  2.22 MB
quay.io/pbertera/pull-test  v2          2a091e613448  3 hours ago  2.22 MB
quay.io/pbertera/pull-test  v1          63010fd24df2  3 hours ago  2.22 MB
<none>                      <none>      f244de9bb82d  3 hours ago  1.08 kB
<none>                      <none>      924c134a6952  3 hours ago  913 MB
docker.io/library/golang    1.24        99a93c486312  2 weeks ago  878 MB

$ podman push quay.io/pbertera/pull-test:latest
```

Check digest and layers of `latest` and `v2` (different digest but same layer):

```
$ skopeo inspect docker://quay.io/pbertera/pull-test:latest | jq -r .Digest,.Layers
sha256:39afa80dcf78da092342588be0e85a99962de3afd3bb9d510e81a45aba91fad2
[
  "sha256:6d32bd19d8d11f4469d5e8cc00a47cde5d66005c25fb945fd5db82b48031a16f"
]

$ skopeo inspect docker://quay.io/pbertera/pull-test:v2 | jq -r .Digest,.Layers
sha256:39afa80dcf78da092342588be0e85a99962de3afd3bb9d510e81a45aba91fad2
[
  "sha256:6d32bd19d8d11f4469d5e8cc00a47cde5d66005c25fb945fd5db82b48031a16f"
]

```

Let's restart the pod:

```
$ oc get pods
NAME                         READY   STATUS    RESTARTS   AGE
pull-test-69c77fccbf-rzppq   1/1     Running   0          165m

$ oc delete pods --all
pod "pull-test-69c77fccbf-rzppq" deleted

$ oc get pods
NAME                         READY   STATUS    RESTARTS   AGE
pull-test-69c77fccbf-5tcvl   1/1     Running   0          6s

$ oc logs deployments/pull-test 
VERSION:  2
```

Let's check the `quay.io/pbertera/pull-test:latest` image on the node:

```
$ oc debug node/ip-10-0-0-191.us-east-2.compute.internal -- chroot /host crictl inspecti quay.io/pbertera/pull-test:latest | jq -r .status.repoDigests
[
  "quay.io/pbertera/pull-test@sha256:39afa80dcf78da092342588be0e85a99962de3afd3bb9d510e81a45aba91fad2"
]
```

The pod is restarted and the image is updated

Lets tag the `v3` as `latest` and push it:

```
$ podman tag quay.io/pbertera/pull-test:v3 quay.io/pbertera/pull-test:latest

$ podman images
REPOSITORY                  TAG         IMAGE ID      CREATED      SIZE
<none>                      <none>      eed2e1c24c11  3 hours ago  1.08 kB
quay.io/pbertera/pull-test  latest      360c2b517e47  3 hours ago  2.22 MB
quay.io/pbertera/pull-test  v3          360c2b517e47  3 hours ago  2.22 MB
<none>                      <none>      4dfc0134d159  3 hours ago  1.08 kB
quay.io/pbertera/pull-test  v2          2a091e613448  3 hours ago  2.22 MB
quay.io/pbertera/pull-test  v1          63010fd24df2  3 hours ago  2.22 MB
<none>                      <none>      f244de9bb82d  3 hours ago  1.08 kB
<none>                      <none>      924c134a6952  3 hours ago  913 MB
docker.io/library/golang    1.24        99a93c486312  2 weeks ago  878 MB

$ podman push quay.io/pbertera/pull-test:latest
Getting image source signatures
Copying blob 6f453ea5985b skipped: already exists  
Copying config 360c2b517e done   | 
Writing manifest to image destination
```

Delete the `v1` and `v2` tags from the repo:

```
$ skopeo delete docker://quay.io/pbertera/pull-test:v1
$ skopeo delete docker://quay.io/pbertera/pull-test:v2
```

Check `v1` and `v2` are missing, `latest` points to `v3`

```
$ skopeo inspect docker://quay.io/pbertera/pull-test:v1
FATA[0000] Error parsing image name "docker://quay.io/pbertera/pull-test:v1": reading manifest v1 in quay.io/pbertera/pull-test: unknown: Tag v1 was deleted or has expired. To pull, revive via time machine 

$ skopeo inspect docker://quay.io/pbertera/pull-test:v2
FATA[0000] Error parsing image name "docker://quay.io/pbertera/pull-test:v2": reading manifest v2 in quay.io/pbertera/pull-test: unknown: Tag v2 was deleted or has expired. To pull, revive via time machine 
```

```
$ skopeo inspect docker://quay.io/pbertera/pull-test:v3
{
    "Name": "quay.io/pbertera/pull-test",
    "Digest": "sha256:3ed7d7750a36778d0b1a3d0f63f90cfec40541f39e8f957444ca63800196a71b",
    "RepoTags": [
        "latest",
        "v3"
    ],
    "Created": "2025-06-20T13:03:39.606355102Z",
    "DockerVersion": "",
    "Labels": {
        "io.buildah.version": "1.33.8"
    },
    "Architecture": "amd64",
    "Os": "linux",
    "Layers": [
        "sha256:6f453ea5985b9787c0343348b4ee9ce43e26854c84afce8e582a37c689ab26b9"
    ],
    "LayersData": [
        {
            "MIMEType": "application/vnd.oci.image.layer.v1.tar+gzip",
            "Digest": "sha256:6f453ea5985b9787c0343348b4ee9ce43e26854c84afce8e582a37c689ab26b9",
            "Size": 1368783,
            "Annotations": null
        }
    ],
    "Env": [
        "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
        "VERSION=3"
    ]
}
```

```
$ skopeo inspect docker://quay.io/pbertera/pull-test:latest
{
    "Name": "quay.io/pbertera/pull-test",
    "Digest": "sha256:3ed7d7750a36778d0b1a3d0f63f90cfec40541f39e8f957444ca63800196a71b",
    "RepoTags": [
        "latest",
        "v3"
    ],
    "Created": "2025-06-20T13:03:39.606355102Z",
    "DockerVersion": "",
    "Labels": {
        "io.buildah.version": "1.33.8"
    },
    "Architecture": "amd64",
    "Os": "linux",
    "Layers": [
        "sha256:6f453ea5985b9787c0343348b4ee9ce43e26854c84afce8e582a37c689ab26b9"
    ],
    "LayersData": [
        {
            "MIMEType": "application/vnd.oci.image.layer.v1.tar+gzip",
            "Digest": "sha256:6f453ea5985b9787c0343348b4ee9ce43e26854c84afce8e582a37c689ab26b9",
            "Size": 1368783,
            "Annotations": null
        }
    ],
    "Env": [
        "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
        "VERSION=3"
    ]
}
```

Now delete the pod:

```
$ oc get pods
NAME                         READY   STATUS    RESTARTS   AGE
pull-test-69c77fccbf-5tcvl   1/1     Running   0          13m

$ oc delete pods --all
pod "pull-test-69c77fccbf-5tcvl" deleted

$ oc get pods
AME                         READY   STATUS    RESTARTS   AGE
pull-test-69c77fccbf-c9kxp   1/1     Running   0          4s

$ oc logs deployments/pull-test
VERSION:  3
```

Let's check the `quay.io/pbertera/pull-test:latest` image on the node:

```
$ oc debug node/ip-10-0-0-191.us-east-2.compute.internal -- chroot /host crictl inspecti quay.io/pbertera/pull-test:latest | jq -r .status.repoDigests
[
  "quay.io/pbertera/pull-test@sha256:3ed7d7750a36778d0b1a3d0f63f90cfec40541f39e8f957444ca63800196a71b"
]
```

The image is properly updated
