def call(String repoUrl, String branch, String tag) {
    withCredentials([usernamePassword(credentialsId: 'github-credentials',
                                     usernameVariable: 'GIT_USER',
                                     passwordVariable: 'GIT_TOKEN')]) {
        sh """
            git config user.email "jenkins@clouddevops.io"
            git config user.name "Jenkins CI"
            git add kubernetes/deployment.yml
            git commit -m "ci: update image tag to ${tag} [skip ci]"
            git push https://\${GIT_USER}:\${GIT_TOKEN}@${repoUrl.replace('https://', '')} ${branch}
        """
    }
    echo "Manifests pushed to repository on branch ${branch}."
}