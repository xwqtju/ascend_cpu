# Ascend CANN 仿真环境 Makefile
IMAGE_85 = ascend-cpu-debug:8.5.0-910b
IMAGE_90 = ascend-cpu-debug:9.0.0-910b
IMAGE    = $(IMAGE_90)

.PHONY: help setup build enter sim-910b sim-950 clean

help:
	@echo "Ascend CANN 仿真环境"
	@echo ""
	@echo "  make setup         一键安装环境"
	@echo "  make enter         进入容器"
	@echo "  make build-aclnn   编译 ACLNN matmul"
	@echo "  make sim-aclnn     仿真 ACLNN matmul (910B PEM)"
	@echo "  make clean         清理编译产物"

setup:
	bash setup.sh 9.0.0 sim

enter:
	IMAGE_NAME=$(IMAGE) bash enter.sh

# ---- ACLNN MatMul ----
build-aclnn:
	docker run --rm --platform linux/arm64 \
		-v "$(PWD):/workspace" -w /workspace/custom_ops/aclnn_matmul \
		$(IMAGE) bash -c '\
			source /etc/profile.d/ascend.sh && \
			INC=/usr/local/Ascend/cann-9.0.0/aarch64-linux/include && \
			LIB64=/usr/local/Ascend/cann-9.0.0/aarch64-linux/lib64 && \
			ASCLIB=/usr/local/Ascend/cann-9.0.0/lib64 && \
			g++ -std=c++17 -O2 -o aclnn_matmul aclnn_matmul.cpp \
				-I$$INC -L$$LIB64 -L$$ASCLIB \
				-lopapi -lascendcl -lnnopbase -lge_runner -lgraph \
				-lregister -lplatform -lrt -ldl -lpthread && \
			echo "aclnn_matmul built"'

gen-data:
	docker run --rm --platform linux/arm64 \
		-v "$(PWD):/workspace" -w /workspace/custom_ops/aclnn_matmul \
		$(IMAGE) bash -c 'mkdir -p input output && python3 gen_data.py'

sim-aclnn: build-aclnn gen-data
	docker run --rm --platform linux/arm64 \
		-v "$(PWD):/workspace" -w /workspace/custom_ops/aclnn_matmul \
		$(IMAGE) bash -c '\
			source /etc/profile.d/ascend.sh && \
			SIMDIR=/usr/local/Ascend/cann-9.0.0/tools/simulator/Ascend910B1/lib && \
			ASCLIB=/usr/local/Ascend/cann-9.0.0/lib64 && \
			DEVLIB=/usr/local/Ascend/cann-9.0.0/devlib/aarch64 && \
			export LD_LIBRARY_PATH=$$SIMDIR:$$ASCLIB:$$DEVLIB:$$LD_LIBRARY_PATH && \
			LD_PRELOAD="libnpu_drv.so:libruntime_cmodel.so:libpem_davinci.so" \
			./aclnn_matmul | grep -E "MatMul|Workspace|done|Errors|PASS|FAIL|tick|stopped"'

clean:
	find . -name "build*" -type d -not -path "*/.git/*" | xargs rm -rf
	find . -name "*.bin" -type f | xargs rm -f
	find . -name "sim_output" -type d | xargs rm -rf
	find . -name "*.toml" -type f | xargs rm -f
	@echo "cleaned"
