#!/bin/bash
docker run -e spring_profiles_active=dev -i -t ${project.artifactId}:${project.version}
