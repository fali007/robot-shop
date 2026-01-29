.PHONY: build push build-multiplatform push-multiplatform create-manifest push-manifest multiplatform-all
IMAGE_REPO := quay.io/agentbench
TAG := latest
PLATFORMS := linux/amd64,linux/arm64

# Services to build
SERVICES := cart catalogue dispatch payment ratings shipping user web mongodb mysql-db
SERVICE_DIRS := cart catalogue dispatch payment ratings shipping user web mongo mysql

# Legacy single platform builds
build:
	docker build --platform linux/amd64 -t $(IMAGE_REPO)/rs-cart:$(TAG) cart/
	docker build --platform linux/amd64 -t $(IMAGE_REPO)/rs-catalogue:$(TAG) catalogue/
	docker build --platform linux/amd64 -t $(IMAGE_REPO)/rs-dispatch:$(TAG) dispatch/
	docker build --platform linux/amd64 -t $(IMAGE_REPO)/rs-payment:$(TAG) payment/
	docker build --platform linux/amd64 -t $(IMAGE_REPO)/rs-ratings:$(TAG) ratings/
	docker build --platform linux/amd64 -t $(IMAGE_REPO)/rs-shipping:$(TAG) shipping/
	docker build --platform linux/amd64 -t $(IMAGE_REPO)/rs-user:$(TAG) user/
	docker build --platform linux/amd64 -t $(IMAGE_REPO)/rs-web:$(TAG) web/
	docker build --platform linux/amd64 -t $(IMAGE_REPO)/rs-mongodb:$(TAG) mongo/
	docker build --platform linux/amd64 -t $(IMAGE_REPO)/rs-mysql-db:$(TAG) mysql/

build-arm:
	docker build  -t $(IMAGE_REPO)/rs-cart:$(TAG) cart/
	docker build  -t $(IMAGE_REPO)/rs-catalogue:$(TAG) catalogue/
	docker build  -t $(IMAGE_REPO)/rs-dispatch:$(TAG) dispatch/
	docker build  -t $(IMAGE_REPO)/rs-payment:$(TAG) payment/
	docker build  -t $(IMAGE_REPO)/rs-ratings:$(TAG) ratings/
	docker build  -t $(IMAGE_REPO)/rs-shipping:$(TAG) shipping/
	docker build  -t $(IMAGE_REPO)/rs-user:$(TAG) user/
	docker build  -t $(IMAGE_REPO)/rs-web:$(TAG) web/
	docker build  -t $(IMAGE_REPO)/rs-mongodb:$(TAG) mongo/
	docker build  -t $(IMAGE_REPO)/rs-mysql-db:$(TAG) mysql/

push:
	docker push $(IMAGE_REPO)/rs-cart:$(TAG)
	docker push $(IMAGE_REPO)/rs-catalogue:$(TAG)
	docker push $(IMAGE_REPO)/rs-dispatch:$(TAG)
	docker push $(IMAGE_REPO)/rs-payment:$(TAG)
	docker push $(IMAGE_REPO)/rs-ratings:$(TAG)
	docker push $(IMAGE_REPO)/rs-shipping:$(TAG)
	docker push $(IMAGE_REPO)/rs-user:$(TAG)
	docker push $(IMAGE_REPO)/rs-web:$(TAG)
	docker push $(IMAGE_REPO)/rs-mongodb:$(TAG)
	docker push $(IMAGE_REPO)/rs-mysql-db:$(TAG)

# Multiplatform builds using Docker Buildx
build-multiarch:
	@echo "Building multi-architecture images with docker buildx..."
	
	# Cart service
	docker buildx build --platform linux/amd64,linux/arm64 --push \
		-t $(IMAGE_REPO)/rs-cart:$(TAG) \
		cart/
	
	# Catalogue service
	docker buildx build --platform linux/amd64,linux/arm64 --push \
		-t $(IMAGE_REPO)/rs-catalogue:$(TAG) \
		catalogue/
	
	# Dispatch service
	docker buildx build --platform linux/amd64,linux/arm64 --push \
		-t $(IMAGE_REPO)/rs-dispatch:$(TAG) \
		dispatch/
	
	# Payment service
	docker buildx build --platform linux/amd64,linux/arm64 --push \
		-t $(IMAGE_REPO)/rs-payment:$(TAG) \
		payment/
	
	# Ratings service
	docker buildx build --platform linux/amd64,linux/arm64 --push \
		-t $(IMAGE_REPO)/rs-ratings:$(TAG) \
		ratings/
	
	# Shipping service
	docker buildx build --platform linux/amd64,linux/arm64 --push \
		-t $(IMAGE_REPO)/rs-shipping:$(TAG) \
		shipping/
	
	# User service
	docker buildx build --platform linux/amd64,linux/arm64 --push \
		-t $(IMAGE_REPO)/rs-user:$(TAG) \
		user/
	
	# Web service
	docker buildx build --platform linux/amd64,linux/arm64 --push \
		-t $(IMAGE_REPO)/rs-web:$(TAG) \
		web/
	
	# MongoDB
	docker buildx build --platform linux/amd64,linux/arm64 --push \
		-t $(IMAGE_REPO)/rs-mongodb:$(TAG) \
		mongo/
	
	# MySQL
	docker buildx build --platform linux/amd64,linux/arm64 --push \
		-t $(IMAGE_REPO)/rs-mysql-db:$(TAG) \
		mysql/
	
	@echo "Multi-architecture images built and pushed successfully!"
	@echo "All images support both linux/amd64 and linux/arm64 architectures"
