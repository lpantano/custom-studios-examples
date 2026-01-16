docker stop igv-test && docker rm igv-test && cd /Users/lop354/Science/nfcore/custom-studios-examples/igv && docker build -t igv-webapp-test .

docker run -d --name igv-test -p 8080:8080 -e CONNECT_TOOL_PORT=8080 -v /Users/lop354/Science/nfcore/custom-studios-examples/igv/test-data:/workspace/data --entrypoint /bin/bash igv-webapp-test -c "generate-session.sh && http-server /app -p 8080 -a 0.0.0.0 --cors"

docker run -d --name igv-test -p 8080:8080 -e CONNECT_TOOL_PORT=8080 -v /Users/lop354/Science/nfcore/custom-studios-examples/igv/test-data:/workspace/data --entrypoint /bin/bash igv-webapp-test -c "generate-session.sh && http-server /app -p 8080 -a 0.0.0.0 --cors"