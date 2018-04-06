import hudson.model.*
import hudson.FilePath
import hudson.EnvVars
import groovy.json.JsonSlurperClassic
import groovy.json.JsonBuilder
import groovy.json.JsonOutput
import java.net.URL
import java.text.SimpleDateFormat

office365ConnectorSend 'https://outlook.office.com/webhook/06ef8305-ea04-466d-b6d3-85ea7529e409@df45f7f9-d3a1-4f0a-a03b-ecfe8093cbb4/JenkinsCI/8dd3641aae524825bc3e2dc68c362a5a/db7d02f4-87f8-4547-9d08-2adbc8afa860'
properties([[$class: 'BuildDiscarderProperty',
                strategy: [$class: 'LogRotator', numToKeepStr: '10']],
                pipelineTriggers([[$class:"SCMTrigger", scmpoll_spec:"H/5 * * * *"]]),
])
node {
        ansiColor('xterm') {
           wrap([$class: 'TimestamperBuildWrapper']) {
                checkout()
                branchvalidate()
                build()
                //integrationtest()
	      	   container()
                warnings()
                archive()
                //clean()
            }

		}
    }
   
def checkout () {   
    step([$class: 'WsCleanup'])         
	stage ('Checkout')
	    checkout scm
		echo "We are currently working on branch: ${env.BRANCH_NAME}"
}

def branchvalidate(){
    sh "echo ${env.BRANCH_NAME}"
        if (env.BRANCH_NAME == 'develop'){
           sonarqube()
        }else{
          println env.BRANCH_NAME
        }
}
def sonarqube () {
        stage('Sonar scan execution') {
            // Run the sonar scan
                script {
                    def mvnHome = tool '3.5.2'
                    withSonarQubeEnv {
                     
                        sh "'${mvnHome}/bin/mvn'  verify sonar:sonar -Dintegration-tests.skip=true -Dmaven.test.failure.ignore=true"
                    }
            }
        }
        // waiting for sonar results based into the configured web hook in Sonar server which push the status back to jenkins
        stage('Sonar scan result check') {
                timeout(time: 2, unit: 'MINUTES') {
                    retry(3) {
                        script {
                            def qg = waitForQualityGate()
                            if (qg.status != 'OK') {
                                error "Pipeline aborted due to quality gate failure: ${qg.status}"
                            }
                        }
                    }
                }
        }    
}
def build () {
    stage('Build with unit testing') {
                // Run the maven build
                script {
                    // Get the Maven tool.
                    // ** NOTE: This 'M3' Maven tool must be configured
                    // **       in the global configuration.
                    echo 'Pulling...' + env.BRANCH_NAME
                    def mvnHome = tool '3.5.2'
                    if (isUnix()) {
                        def targetVersion = getDevVersion()
                        print 'target build version...'
                        print targetVersion
                        sh "'${mvnHome}/bin/mvn' -Dintegration-tests.skip=true -Dbuild.number=${targetVersion} clean package"
                        def pom = readMavenPom file: 'pom.xml'
                        // get the current development version 
                        developmentArtifactVersion = "${pom.version}-${targetVersion}"
                        print pom.version
                        // execute the unit testing and collect the reports
                        junit allowEmptyResults: true, testResults: '**/target/surefire-reports/TEST-*.xml'
                    } else {
                        bat(/"${mvnHome}\bin\mvn" -Dintegration-tests.skip=true clean package/)
                        def pom = readMavenPom file: 'pom.xml'
                        print pom.version
                        junit '**//*target/surefire-reports/TEST-*.xml'
                    }
                }

        }
 
}

def integrationtest() {
        stage('Integration tests') {
            // Run integration test
                script {
                    def mvnHome = tool '3.5.2'
                    if (isUnix()) {
                        // just to trigger the integration test without unit testing
                        sh "'${mvnHome}/bin/mvn'  verify -Dunit-tests.skip=true"
                    } else {
                        bat(/"${mvnHome}\bin\mvn" verify -Dunit-tests.skip=true/)
                    }

                }
        }
}


def developmentArtifactVersion = ''
def releasedVersion = ''
// get change log to be send over the mail
@NonCPS
def getChangeString() {
    MAX_MSG_LEN = 100
    def changeString = ""

    echo "Gathering SCM changes"
    def changeLogSets = currentBuild.changeSets
    for (int i = 0; i < changeLogSets.size(); i++) {
        def entries = changeLogSets[i].items
        for (int j = 0; j < entries.length; j++) {
            def entry = entries[j]
            truncated_msg = entry.msg.take(MAX_MSG_LEN)
            changeString += " - ${truncated_msg} [${entry.author}]\n"
        }
    }

    if (!changeString) {
        changeString = " - No new changes"
    }
    return changeString
}

def sendEmail(status) {
    mail(
            to: "$EMAIL_RECIPIENTS",
            subject: "Build $BUILD_NUMBER - " + status + " (${currentBuild.fullDisplayName})",
            body: "Changes:\n " + getChangeString() + "\n\n Check console output at: $BUILD_URL/console" + "\n")
}

def getDevVersion() {
    def gitCommit = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
    def versionNumber;
    if (gitCommit == null) {
        versionNumber = env.BUILD_NUMBER;
    } else {
        versionNumber = gitCommit.take(8);
    }
    print 'build  versions...'
    print versionNumber
    return versionNumber
}

def getReleaseVersion() {
    def pom = readMavenPom file: 'pom.xml'
    def gitCommit = sh(returnStdout: true, script: 'git rev-parse HEAD').trim()
    def versionNumber;
    if (gitCommit == null) {
        versionNumber = env.BUILD_NUMBER;
    } else {
        versionNumber = gitCommit.take(8);
    }
    return pom.version.replace("-SNAPSHOT", ".${versionNumber}")
}

def container (){
    def customImage
    stage('Build image') {
	withDockerRegistry([credentialsId: 'nexus', url: 'http://nexus.verity.local:18443']) {
	  customImage = docker.build("nexus.verity.local:18440/pause-web:${env.BUILD_ID}-${env.BUILD_TIMESTAMP}")
    }
   }	
    stage('Push image') {
       customImage.push()
       customImage.push('latest')
    }
    stage('Deploy image') {
       rancher confirm: true, credentialId: 'rancher-server', endpoint: 'http://192.168.3.22:8080/v2-beta', environmentId: '1a5', environments: '', image: 'nexus.verity.local:18443/pause-web:latest', ports: '9001', service: 'pause/pause-web', timeout: 50
    }
	
}

def warnings(){
  stage ('Warnings')
    warnings canComputeNew: false, canResolveRelativePaths: false, categoriesPattern: '', consoleParsers: [[parserName: 'Java Compiler (javac)'], [parserName: 'JavaDoc Tool'], [parserName: 'Maven']], defaultEncoding: '', excludePattern: '', healthy: '', includePattern: '', messagesPattern: '', unHealthy: ''
}

def archive(){
  stage ('Archive'){
 	archiveArtifacts artifacts: '**/*.war', onlyIfSuccessful: true
  }
}

def clean(){
  stage ('Delete Workpspace'){
    deleteDir()
  }
}
