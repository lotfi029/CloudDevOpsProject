def call(String imageName, String tag, String ecrUrl) {
    sh """
        docker rmi ${imageName}:${tag} || true
        docker rmi ${ecrUrl}/${imageName}:${tag} || true
    """
    echo "Local images deleted."
}