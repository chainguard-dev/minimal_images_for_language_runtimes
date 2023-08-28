# Building Minimal Images for Languages with Runtimes

This is a short tutorial on using Chainguard Images to build minimal images for languages with
runtimes. We'll look an example with the Chainguard Maven and JRE images to build and run the
Java petclinic application, followed by doing the same thing in wolfi-base in order to pin versions.

We're using the spring boot version of the [Java petclinic
application](https://github.com/spring-projects/spring-petclinic) to provide a non-trivial example.


## Building with the Chainguard Maven and JRE images

Start by getting the petclinic code:
```
git clone https://github.com/spring-projects/spring-petclinic.git
cd spring-petclinic
```

Now copy the Dockerfile from this repo into the project. It should look like:

```
$ cat Dockerfile:
FROM cgr.dev/chainguard/maven as build

WORKDIR /app

COPY .mvn/ .mvn
COPY mvnw pom.xml ./
COPY src ./src
RUN ./mvnw package

FROM cgr.dev/chainguard/jre

COPY --from=build /app/target/spring-petclinic-3.1.0-SNAPSHOT.jar /

ENTRYPOINT ["java", "-jar", "/spring-petclinic-3.1.0-SNAPSHOT.jar"]
```

This is a two-stage build, but we can build the just the first stage by passing the `target` argument to `docker build`:

```
docker build -t petclinic-build --target build .
```

If we look at this image, it's pretty large:

```
$ docker images petclinic-build
REPOSITORY        TAG       IMAGE ID       CREATED      SIZE
petclinic-build   latest    126140c27655   3 days ago   723MB
```

Let's build the main image this time:

```
docker build -t petclinic .
```

And take a look at the size:

```
$ docker images petclinic
REPOSITORY   TAG       IMAGE ID       CREATED      SIZE
petclinic    latest    aca628385473   3 days ago   332MB
```

Because this image doesn't have Maven, the full JDK, or all the build sources, it is less than half
the size.

Finally, it's worth running it with:

```
$ docker run -p 8080:8080 petclinic
```

You should be able to browse to localhost:8080 to see the application in action.

It's important to note that the Dockefile above uses the `latest` version of both the maven image
and the JRE. In some cases this can be problematic, as you may want to pin Java versions to ensure
compatability. The easiest way to achieve this is to buy a Chainguard Images subscription, which
will give you access to tagged versions of the images for all supported Java versions. If that's not
possible, you can use the wolfi-base image to build images with explicit versions of the Java and
Maven packages.

## Building with the wolfi-base image

We can modify the previous example to use the wolfi-base image:

```
$ cat Dockerfile-wolfi
FROM cgr.dev/chainguard/wolfi-base as build

RUN apk update && apk add openjdk-17 maven~3.9

WORKDIR /app
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk

COPY .mvn/ .mvn
COPY mvnw pom.xml ./
COPY src ./src
RUN ./mvnw package

FROM cgr.dev/chainguard/wolfi-base

RUN apk update && apk add openjdk-17-default-jvm

# Some Java apps may require extra locale files
# RUN apk add glibc-locale-en

USER nonroot

COPY --from=build /app/target/spring-petclinic-3.1.0-SNAPSHOT.jar /

ENTRYPOINT ["java", "-jar", "/spring-petclinic-3.1.0-SNAPSHOT.jar"]
```

Let's build it and look at the size:

```
$ docker build -t petclinic-wolfi -f Dockerfile-wolfi .
...
$ docker images petclinic-wolfi
REPOSITORY        TAG       IMAGE ID       CREATED      SIZE
petclinic-wolfi   latest    063ed44f7ba4   3 days ago   276MB
```

There's a couple of things to note here. 

The first is that the new image is actually _smaller_ than the previous image, which you
may not have expected. It turns out the JRE image includes a large amount of "locale" files, which
are required by some Java applications. If this includes your application, you will need to add a
line like `RUN apk add glibc-locale-en` (which is commented out above).

The second is that our final image has more packages than the previous image, most notably inlcuding
a package manager and shell. This increases the complexity and attack surface of the image. In a lot
of cases this trade-off will be worth it for the extra control of the packages present.

## Conclusion

The techniques in these Dockefiles allow you to build minimal, secure images for common language
ecosystems. We looked at an example in Java, but the techniques should be directly applicable to
other language ecosystems, including Python, Node and Ruby. 

