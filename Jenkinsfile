stage('Build') {
  parallel (
    "linux64": {
      node("lin64") {
        checkout scm
        retry(2) {
            sh 'bash -ic "nvm install v6.9.4; nvm exec v6.9.4 ./script/build --compress-artifacts"'
        }
        archiveArtifacts allowEmptyArchive: true, artifacts: 'out/*.tar.gz', onlyIfSuccessful: true
      }
    },
    "linux86": {
      node("lin86") {
        checkout scm
        retry(2) {
            sh 'bash -ic "nvm install v6.9.4; nvm exec v6.9.4 ./script/build --compress-artifacts"'
        }
        archiveArtifacts allowEmptyArchive: true, artifacts: 'out/*.tar.gz', onlyIfSuccessful: true
      }
    },
    "windows64": {
      node("windows") {
        checkout scm
        retry(2) {
            powershell '''
            Install-NodeVersion v6.9.4 -Force -Architecture amd64
            Set-NodeVersion v6.9.4
            .\\script\\build.cmd --compress-artifacts
            '''
        }
        archiveArtifacts allowEmptyArchive: true, artifacts: 'out/*.zip', onlyIfSuccessful: true
      }
    },
    "windows32": {
      node("windows") {
        checkout scm
        retry(2){
            powershell '''
            Install-NodeVersion v6.9.4 -Force -Architecture X86
            Set-NodeVersion v6.9.4
            .\\script\\build.cmd --compress-artifacts
            '''
        }
        archiveArtifacts allowEmptyArchive: true, artifacts: 'out/*.zip', onlyIfSuccessful: true
      }
    }
  )
}
