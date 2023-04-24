.PHONY: build docker test clean prepare update

# see https://shibumi.dev/posts/hardening-executables
CGO_CPPFLAGS="-D_FORTIFY_SOURCE=2"
CGO_CFLAGS="-O2 -pipe -fno-plt"
CGO_CXXFLAGS="-O2 -pipe -fno-plt"
CGO_LDFLAGS="-Wl,-O1,–sort-common,–as-needed,-z,relro,-z,now"

MICROSERVICES=cmd/device-usb-camera
.PHONY: $(MICROSERVICES)

# VERSION file is not needed for local development, In the CI/CD pipeline, a temporary VERSION file is written
VERSION=$(shell cat ./VERSION 2>/dev/null || echo 0.0.0)

# This pulls the version of the SDK from the go.mod file
SDKVERSION=$(shell cat ./go.mod | grep 'github.com/edgexfoundry/device-sdk-go/v3 v' | awk '{print $$2}')

GIT_SHA=$(shell git rev-parse HEAD)
GOFLAGS=-ldflags "-X github.com/edgexfoundry/device-usb-camera.Version=$(VERSION)" -trimpath -mod=readonly

ARCH=$(shell uname -m)

build: $(MICROSERVICES)

build-nats:
	make -e ADD_BUILD_TAGS=include_nats_messaging build

# A go module in this service needs CGO
cmd/device-usb-camera:
	go build -tags "$(ADD_BUILD_TAGS)" $(GOFLAGS) -o $@ ./cmd

docker:
	docker build . \
		--build-arg ADD_BUILD_TAGS=$(ADD_BUILD_TAGS) \
		--label "git_sha=$(GIT_SHA)" \
		-t edgexfoundry/device-usb-camera:$(GIT_SHA) \
		-t edgexfoundry/device-usb-camera:$(VERSION)-dev

docker-nats:
	make -e ADD_BUILD_TAGS=include_nats_messaging docker

tidy:
	go mod tidy

unittest:
	go test -json ./... -coverprofile=coverage.out ./...

lint:
	@which golangci-lint >/dev/null || echo "WARNING: go linter not installed. To install, run make install-lint"
	@if [ "z${ARCH}" = "zx86_64" ] && which golangci-lint >/dev/null ; then golangci-lint run --config .golangci.yml ; else echo "WARNING: Linting skipped (not on x86_64 or linter not installed)"; fi

install-lint:
	sudo curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $$(go env GOPATH)/bin v1.51.2

test: unittest lint
	go vet ./...
	gofmt -l $$(find . -type f -name '*.go'| grep -v "/vendor/")
	[ "`gofmt -l $$(find . -type f -name '*.go'| grep -v "/vendor/")`" = "" ]
	./bin/test-attribution-txt.sh

coveragehtml:
	go tool cover -html=coverage.out -o coverage.html

format:
	gofmt -l $$(find . -type f -name '*.go'| grep -v "/vendor/")
	[ "`gofmt -l $$(find . -type f -name '*.go'| grep -v "/vendor/")`" = "" ]

update:
	go mod download

clean:
	rm -f $(MICROSERVICES)

vendor:
	go mod vendor
