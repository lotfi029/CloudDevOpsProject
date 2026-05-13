def call(String ecrUrl, String imageName, String tag, String region) {
    sh """
        aws ecr get-login-password --region ${region} | \
        docker login --username AWS --password-stdin ${ecrUrl}
        docker tag ${imageName}:${tag} ${ecrUrl}/${imageName}:${tag}
        docker push ${ecrUrl}/${imageName}:${tag}
    """
    echo "Image pushed to ECR: ${ecrUrl}/${imageName}:${tag}"
}