#!/bin/bash

source ~/.openrc

heat stack-delete rpc-jenkins-${BUILD_NUMBER}
