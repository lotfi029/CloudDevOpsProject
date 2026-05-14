# 6. Continuous Integration with Jenkins

## ✅ Requirement Status

| Requirement | Status |
|-------------|--------|
| Stage: Build Image | ✅ Done — `buildImage.groovy` |
| Stage: Scan Image | ✅ Done — `scanImage.groovy` (Trivy) |
| Stage: Push Image | ✅ Done — `pushImage.groovy` (ECR) |
| Stage: Delete Image Locally | ✅ Done — `deleteLocalImage.groovy` |
| Stage: Update Manifests | ✅ Done — `updateManifests.groovy` |
| Stage: Push Manifests | ✅ Done — `pushManifests.groovy` |
| Use Shared Library | ✅ Done — `jenkins/shared-library/vars/` |
| Jenkinsfile committed | ✅ Done — `jenkins/Jenkinsfile` |
| Shared library `vars/` committed | ✅ Done |

---

## Pipeline Overview

```
Build Image → Scan Image → Push Image → Delete Local → Update Manifests → Push Manifests
     ✅            ✅           ✅            ✅               ✅                ✅
```

---

## `jenkins/Jenkinsfile`

```groovy
@Library('clouddevops-shared-library') _

pipeline {
    agent any
    environment {
        IMAGE_NAME = "clouddevops-app"
        ECR_URL    = "108782058667.dkr.ecr.us-east-1.amazonaws.com"
        AWS_REGION = "us-east-1"
        REPO_URL   = "https://github.com/lotfi029/CloudDevOpsProject.git"
        GIT_BRANCH = "main"
        IMAGE_TAG  = "${BUILD_NUMBER}"
    }
    stages {
        stage('Build Image')         { steps { script { buildImage(env.IMAGE_NAME, env.IMAGE_TAG) } } }
        stage('Scan Image')          { steps { script { scanImage(env.IMAGE_NAME, env.IMAGE_TAG) } } }
        stage('Push Image')          { steps { script { pushImage(env.ECR_URL, env.IMAGE_NAME, env.IMAGE_TAG, env.AWS_REGION) } } }
        stage('Delete Image Locally'){ steps { script { deleteLocalImage(env.IMAGE_NAME, env.IMAGE_TAG, env.ECR_URL) } } }
        stage('Update Manifests')    { steps { script { updateManifests(env.IMAGE_NAME, env.IMAGE_TAG, env.ECR_URL) } } }
        stage('Push Manifests')      { steps { script { pushManifests(env.REPO_URL, env.GIT_BRANCH, env.IMAGE_TAG) } } }
    }
    post {
        always { cleanWs() }
    }
}
```

---

## Shared Library — `jenkins/shared-library/vars/`

### `buildImage.groovy`
```groovy
def call(String imageName, String tag) {
    sh "docker build -t ${imageName}:${tag} ."
}
```

### `scanImage.groovy`
```groovy
def call(String imageName, String tag) {
    sh "trivy image --exit-code 0 --severity HIGH,CRITICAL ${imageName}:${tag}"
}
```
> `--exit-code 0` means the pipeline continues even if vulnerabilities are found — they are reported, not blocking.

### `pushImage.groovy`
```groovy
def call(String ecrUrl, String imageName, String tag, String region) {
    sh """
        aws ecr get-login-password --region ${region} | \
        docker login --username AWS --password-stdin ${ecrUrl}
        docker tag ${imageName}:${tag} ${ecrUrl}/${imageName}:${tag}
        docker push ${ecrUrl}/${imageName}:${tag}
    """
}
```

### `deleteLocalImage.groovy`
```groovy
def call(String imageName, String tag, String ecrUrl) {
    sh """
        docker rmi ${imageName}:${tag} || true
        docker rmi ${ecrUrl}/${imageName}:${tag} || true
    """
}
```

### `updateManifests.groovy`
```groovy
def call(String imageName, String tag, String ecrUrl) {
    sh "sed -i 's|image: .*|image: ${ecrUrl}/${imageName}:${tag}|g' kubernetes/deployment.yml"
}
```

### `pushManifests.groovy`
```groovy
def call(String repoUrl, String branch, String tag) {
    withCredentials([usernamePassword(credentialsId: 'github-credentials',
                                     usernameVariable: 'GIT_USER',
                                     passwordVariable: 'GIT_TOKEN')]) {
        sh """
            git config user.email "jenkins@clouddevops.io"
            git config user.name "Jenkins CI"
            git checkout -B ${branch}
            git add kubernetes/deployment.yml
            git commit -m "ci: update image tag to ${tag} [skip ci]"
            git push https://\${GIT_USER}:\${GIT_TOKEN}@${repoUrl.replace('https://', '')} ${branch}
        """
    }
}
```
> `git checkout -B` creates a local branch from the detached HEAD state — required because Jenkins checks out in detached HEAD mode.

---

## Jenkins Setup

### Required Credentials

| ID | Type | Used For |
|----|------|----------|
| `github-credentials` | Username + Password (token) | Push manifests to GitHub |
| AWS IAM Role (instance profile) | EC2 Instance Profile | ECR login, no hardcoded keys |

### Shared Library Configuration

**Manage Jenkins → Configure System → Global Pipeline Libraries:**

| Field | Value |
|-------|-------|
| Name | `clouddevops-shared-library` |
| Default version | `main` |
| Source | Git |
| Repository URL | `https://github.com/lotfi029/CloudDevOpsProject.git` |
| Library path | `jenkins/shared-library` |

### Pipeline Job Configuration

1. New Item → `clouddevops-pipeline` → Pipeline
2. Pipeline script from SCM → Git
3. Repository URL: `https://github.com/lotfi029/CloudDevOpsProject.git`
4. Credentials: `github-credentials`
5. Branch: `*/main`
6. Script Path: `jenkins/Jenkinsfile`

---

## IAM Permissions Required

The Jenkins EC2 instance needs an IAM role with:

```json
{
  "Statement": [
    { "Effect": "Allow", "Action": "ecr:GetAuthorizationToken", "Resource": "*" },
    { "Effect": "Allow", "Action": ["ecr:PutImage", "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload"],
      "Resource": "arn:aws:ecr:us-east-1:108782058667:repository/clouddevops-app" },
    { "Effect": "Allow", "Action": ["eks:DescribeCluster", "eks:ListClusters"], "Resource": "*" }
  ]
}
```

---

## Successful Build Output (Build #6)

```
✅ Build Image       — clouddevops-app:6 built
✅ Scan Image        — 7 HIGH (debian), 3 HIGH (python-pkg), 0 secrets
✅ Push Image        — pushed to ECR :6
✅ Delete Locally    — images removed
✅ Update Manifests  — deployment.yml patched with tag :6
✅ Push Manifests    — committed and pushed to GitHub main
```