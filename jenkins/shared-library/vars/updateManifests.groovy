def call(String imageName, String tag, String ecrUrl) {
    sh """
        sed -i 's|image: .*|image: ${ecrUrl}/${imageName}:${tag}|g' kubernetes/deployment.yml
    """
    echo "Kubernetes manifests updated with new image tag: ${tag}"
}