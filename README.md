Docker image from maven: docker-maven-plugin
---------------------------------------------------

**I wanted to try out building a Docker image straight out of maven, even though I personally don't think this would be a good practice**.
I believe the better approach is to seperate both concerns and have a docker image built upon commit in a repository (or something along these lines, with dockerhub or codeship).

Back to building a docker image with a maven plugin, here's the plugins I found:
* https://github.com/spotify/docker-maven-plugin
* https://github.com/fabric8io/docker-maven-plugin
* https://github.com/wouterd/docker-maven-plugin
* https://github.com/alexec/docker-maven-plugin

fabric8io included a comparison on his github: [fabric8io's github](https://github.com/fabric8io/shootout-docker-maven)

I didn't try them all out, the first one I used was spotify's and it worked like a charm, so i stick with it:

```
<plugin>
    <groupId>com.spotify</groupId>
    <artifactId>docker-maven-plugin</artifactId>
</plugin>
```

All I'm really doing is building my maven artifact, then package it in a linux-jdk8 Docker image.
So I'm sure the other plugins would have worked just as good.

**Maven configuration**

Here's how I configured the plugin:
```
<plugin>
    <groupId>com.spotify</groupId>
    <artifactId>docker-maven-plugin</artifactId>
    <version>0.4.11</version>
    <executions>
        <execution>
            <phase>package</phase>
            <goals>
                <goal>build</goal>
            </goals>
        </execution>
    </executions>
    <configuration>
        <imageName>${project.artifactId}</imageName>
        <dockerDirectory>${basedir}/target/docker</dockerDirectory>
        <imageTags><imageTag>${project.version}</imageTag></imageTags>
        <resources>
            <resource>
                <targetPath>/</targetPath>
                <directory>${project.build.directory}</directory>
                <include>${project.build.finalName}.jar</include>
            </resource>
        </resources>
    </configuration>
</plugin>
```

* **execution>phase>package**: the plugin is bound to the package phase, so the Docker image is created every time an ```mvn install``` is performed.
This may not be the best solution, but it is simply the easiest for my purposes.
* **imageName**: the image name is the artifactId;
* **dockerDirectory**: the plugin looks for a Dockerfile in target/docker (see maven-resources-plugin below)
* **imageTag**: the image tag is the project's version
* **resource>include**: The artifact jar is included in the resources visible to the Dockerfile


I keep my actual Dockerfile ```src/main/docker```:

```
FROM frolvlad/alpine-oraclejdk8:slim
VOLUME /tmp
ADD ${artifactId}-${version}.jar ${artifactId}-${version}.jar
ENTRYPOINT ["java","-jar","/${artifactId}-${version}.jar"]
```

* **FROM frolvlad/alpine-oraclejdk8:slim**: an image I found on dockerhub with all I need, jdk8;
* **ADD ${artifactId}-${version}.jar ${artifactId}-${version}.jar**: add the artifact into the Docker image
* **ENTRYPOINT ["java","-jar","/${artifactId}-${version}.jar"]**: execute the application on startup


As you can see, instead of harcoding the values in the Dockerfile, I used maven properties.
For this to work, I then need to use maven's ```filtering``` feature. In a perfect world, the ```docker-maven-plugin``` would support filtering. 
Perhaps it works with the other docker-maven-plugins, I didn't want to lose any sleep on that: [spotify's open issue on this](https://github.com/spotify/docker-maven-plugin/issues/25)

So I simply used ```maven-resources-plugin``` to copy the Dockerfile into the target directory, while applying filtering.
This is why the ```docker-maven-plugin``` looks for the Dockerfile in ```target/docker``` instead of ```src/main/docker``` :
```
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-resources-plugin</artifactId>
    <version>3.0.1</version>
    <executions>
        <execution>
            <id>copy-resources</id>
            <phase>process-resources</phase>
            <goals>
                <goal>copy-resources</goal>
            </goals>

            <configuration>
                <outputDirectory>${basedir}/target/docker</outputDirectory>
                <resources>
                    <resource>
                        <directory>src/main/docker</directory>
                        <filtering>true</filtering>
                    </resource>
                </resources>
            </configuration>
        </execution>
    </executions>
</plugin>
```
Building and launching
------------------------
Now, all that is left to do is to actually do it:

    $ git clone  https://github.com/alexturcot/sample-docker-from-maven.git
    $ cd sample-docker-from-maven
    $ mvn clean install
```    
[INFO] Scanning for projects...
[INFO]                                                                         
[INFO] ------------------------------------------------------------------------
[INFO] Building sample-docker-from-maven 1.0.0-SNAPSHOT
[INFO] ------------------------------------------------------------------------
[INFO] 
[INFO] --- maven-clean-plugin:2.5:clean (default-clean) @ sample-docker-from-maven ---
[INFO] Deleting /Users/alexbt/IdeaProjects/sample-docker-from-maven/target
[INFO] 
[INFO] --- maven-resources-plugin:3.0.1:resources (default-resources) @ sample-docker-from-maven ---
[INFO] Using 'UTF-8' encoding to copy filtered resources.
[INFO] Copying 1 resource
...
[INFO] Copying /Users/alexbt/IdeaProjects/sample-docker-from-maven/target/sample-docker-from-maven-1.0.0-SNAPSHOT.jar -> /Users/alexbt/IdeaProjects/sample-docker-from-maven/target/docker/sample-docker-from-maven-1.0.0-SNAPSHOT.jar
[INFO] Copying /Users/alexbt/IdeaProjects/sample-docker-from-maven/target/docker/Dockerfile -> /Users/alexbt/IdeaProjects/sample-docker-from-maven/target/docker/Dockerfile
[INFO] Copying /Users/alexbt/IdeaProjects/sample-docker-from-maven/target/docker/sample-docker-from-maven-1.0.0-SNAPSHOT.jar -> /Users/alexbt/IdeaProjects/sample-docker-from-maven/target/docker/sample-docker-from-maven-1.0.0-SNAPSHOT.jar
[INFO] Building image sample-docker-from-maven
Step 1 : FROM frolvlad/alpine-oraclejdk8:slim
Pulling from frolvlad/alpine-oraclejdk8
e110a4a17941: Downloading [==================================>                ] 
e110a4a17941: Downloading [=========================================>         ] 
1.932 MB/2.31 MBwnloading [==============================>                    ] 
1.834 MB/3.007 MB
...
[IFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------

```
You'll see the image in docker if you type :

    $ docker images
   
```
REPOSITORY                        TAG                 IMAGE ID            CREATED             SIZE
sample-docker-from-maven         1.0.0-SNAPSHOT      c9e136ec0738        5 minutes ago       201.8 MB
```

Then, you can launch the container:

    $ docker run -e spring_profiles_active=dev -p 8080:8080 -i -t sample-docker-from-maven:1.0.0-SNAPSHOT
    
In my case, the entrypoint of my image is a spring boot application.
* **-e spring_profiles_active=dev**  is to provide set a spring profile
* **-p 8080:8080** is to open port on the docker container, so that I can reach it from my computer.

You can browse to http://localhost:8080/docker, to access the dockerized application. That's it.