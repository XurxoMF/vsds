# Welcome to VSDS

VSDS it's an abbreviation of Vintage Story Dockerized Server.

In this project you can find all the Dockercompose files used to generate the different Docker Images fro Vintage Story Servers.

## How can I make a server using the docker images?

Running a server with this images is really easy. First of all create a folder called `data` where you want. For example `/home/youruser/servername/data`.

```sh
cd ~
mkdir servername && cd servername
mkdir data
```

Now that you have the folder created you can just start the server with this command:

On Linux:

```sh
docker run -d --name ContainerName \
  -e UID=$(id -u) -e GID=$(id -g) \
  -p 42420:42420 \
  -v /home/youruser/servername/data:/data \
  --restart unless-stopped \
  xurxomf/vsds:X.X.X
```

On MacOS and Windows:

```sh
docker run -d --name ContainerName \
  -p 42420:42420 \
  -v /home/youruser/servername/data:/data \
  --restart unless-stopped \
  xurxomf/vsds:X.X.X
```

- `ContainerName` must be replaced with the name you want to give to the container.
- `UID` and `GID` must match your local user and group ids. If id -u and id -g doesn't work, replace them with the needed ids.
- `42420:42420` can be changed if you have multiple servers. It's `local:container` so change the first half like `12345:42420`.
- `/home/youruser/servername/data` must be replaced with the path to your data folder. You can use relative paths like `./data`.
- `X.X.X` must be replaced with the version to use, for example: latest, stable, rc, 1.20.12, 1.21.0-rc.1....
  - `latest` is the latest available version, stable and rc.
  - `stable` is the latest stable release.
  - `rc` is the latest rc.
  - `1.20.12` and `1.21.0-rc.1` are specific versions.

Right now you've your server running, or it should. If it's running but not letting users connect, make sure to open the local port on your firewall and router. Default prot is `42420`.

Once this is working you'll have a basic default server up and running. Now you can:

- Install mods.
- Change server settings.
- Customize your wold.
- Etc...

To do all this things you need so stop the container, make changes and start it again. You can do this with:

```sh
docker stop ContainerName # This will stop the server.
# Make the changed you need.
docker start ContainerName # This will start the server again.
```

### How can I customize the world and server settings?

After stopping the server, edit the `.../data/serverconfig.json` file and modify anything you need!

You've a full list of configs here: [Vintage Story Wiki > clientsettings.json](https://wiki.vintagestory.at/Server_Config)

If you changed world settings you'll need to delete the old world and player data. To do this just delete the `.../data/Saves` and `.../data/Playerdata` folders.

Now that everything is configured just start the server again.

### How can I install mods?

This is really easy. First of all stop the server. Once the server is stopped just download the mods you need inside the `.../data/Mods` folder.

If you installed or removed mods that change many things like world generation you'll need to delete the old world and player data. To do this just delete the `.../data/Saves` and `.../data/Playerdata` folders.

Now that all the mods are downloaded just start the server again.

### How can I see server logs?

If you need to see the server logs you can just check the files under `.../data/Logs`. Those are the Vintage Story Server logs.

If you need to see the container logs you can use the following command:

```sh
docker logs ContainerName
```

### How can I execute commands on the server?

If you need to execute a command on the container/server just use the next command:

```sh
docker exec -it ContainerName <command>
```

If you need to open the server terminal use this command instead:

```sh
docker attach ContainerName
```

Here you'll be able to execute any command you want. Once you've finished just press `Ctrl + P and then Ctrl + Q`. This will close the terminal but keep the container running.

## How can I generate an image?

You don't need to do this, you can just use the ones I've uploaded to Docker Hub but, if you need to do so, open the folder of the version you need and then you can use this command:

```sh
docker build -t ImageName:X.X.X .
```

- `ImageName` is the name of your image.
- `X.X.X` is the tag of that version. Usually the version of the server.
