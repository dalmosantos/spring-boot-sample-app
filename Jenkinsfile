import hudson.model.*
import hudson.FilePath
import hudson.EnvVars
import groovy.json.JsonSlurperClassic
import groovy.json.JsonBuilder
import groovy.json.JsonOutput
import java.net.URL
node {
      wrap([$class: 'TimestamperBuildWrapper']) {
           checkout()
           branchvalidate()
           build()
           integrationtest()
		   deploydev()
           warnings()
           //archive()
           clean()
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
            steps {
                script {
                    def mvnHome = tool '3.5.2'
                    withSonarQubeEnv {
                     
                        sh "'${mvnHome}/bin/mvn'  verify sonar:sonar -Dintegration-tests.skip=true -Dmaven.test.failure.ignore=true"
                    }
                }
            }
        }
        // waiting for sonar results based into the configured web hook in Sonar server which push the status back to jenkins
        stage('Sonar scan result check') {
            steps {
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
                        archive 'target*//*.jar'
                    } else {
                        bat(/"${mvnHome}\bin\mvn" -Dintegration-tests.skip=true clean package/)
                        def pom = readMavenPom file: 'pom.xml'
                        print pom.version
                        junit '**//*target/surefire-reports/TEST-*.xml'
                        archive 'target*//*.jar'
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
	    stage('DEV sanity check') {
                // give some time till the deployment is done, so we wait 45 seconds
                sleep(45)
                script {
                    if (currentBuild.result == null || currentBuild.result == 'SUCCESS') {
                        timeout(time: 1, unit: 'MINUTES') {
                            script {
                                def mvnHome = tool '3.5.2'
                                //NOTE : if u change the sanity test class name , change it here as well
                                sh "'${mvnHome}/bin/mvn' -Dtest=ApplicationSanityCheck_ITT surefire:test"
                            }

                        }
                    }
                }
        }
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
