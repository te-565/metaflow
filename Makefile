# Based on: https://towardsdatascience.com/create-virtualenv-for-data-science-projects-with-one-command-only-7bec3548419f

# Load in Environment Variables
include .env
export $(shell sed 's/=.*//' .env)

# Variables
ACTIVATE = source $$(conda info --base)/etc/profile.d/conda.sh ; conda activate ; conda activate
DEACTIVATE = source $$(conda info --base)/etc/profile.d/conda.sh ; conda deactivate ; conda deactivate

# Help
.DEFAULT_GOAL := help
.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'


# Environment Management
.PHONY: create-environment 
create-environment: ## Create the env, install packages, create a kernel and write to environment.yaml
	conda create --name $(CONDA_ENVIRONMENT_NAME) --channel conda-forge --yes python=$(PYTHON_VERSION)
	$(ACTIVATE) $(CONDA_ENVIRONMENT_NAME) && \
	conda config --add channels conda-forge && \
	conda config --set channel_priority strict && \
	conda install --yes --file requirements-conda.txt && \
	pip install -r requirements-pip.txt && \
	conda env export > environment.yaml
	$(DEACTIVATE)

.PHONY: install-all-requirements
install-all-requirements: ## Install packages in requirements-conda & requirements-pip and write to environment.yaml
	$(ACTIVATE) $(CONDA_ENVIRONMENT_NAME) && \
	conda install --yes --file requirements-conda.txt && \
	pip install -r requirements-pip.txt && \
	conda env export > environment.yaml
	$(DEACTIVATE)

.PHONY: install-conda-requirements
install-conda-requirements: ## Install packages in requirements-conda file and write to environment.yaml
	$(ACTIVATE) $(CONDA_ENVIRONMENT_NAME) && \
	conda install --yes --file requirements-conda.txt && \
	conda env export > environment.yaml
	$(DEACTIVATE)


.PHONY: install-pip-requirements
install-pip-requirements: ## Install the packages in the requirements-pip file and write to environment.yaml
	$(ACTIVATE) $(CONDA_ENVIRONMENT_NAME) && \
	pip install -r requirements-pip.txt && \
	conda env export > environment.yaml
	$(DEACTIVATE) 

.PHONY: remove-environment 
remove-environment: ## Remove the environment and any relevant files
	conda env remove --name $(CONDA_ENVIRONMENT_NAME)


# Jupyter kernel management
.PHONY: create-kernel
create-kernel: ## Register the conda environment to Jupyter
	$(ACTIVATE) $(CONDA_ENVIRONMENT_NAME) && \
	ipython kernel install --user --name=$(CONDA_ENVIRONMENT_NAME)
	$(DEACTIVATE) 

.PHONY: remove-kernel
remove-kernel: ## Remove the conda environment from Jupyter
	jupyter kernelspec uninstall $(CONDA_ENVIRONMENT_NAME)

# Execution
.PHONY: run-experiment
run-experiment: ## For experimentation: Runs the pipeline
	$(ACTIVATE) $(CONDA_ENVIRONMENT_NAME) && \
	python -m main
	$(DEACTIVATE)

.PHONY: run-deployment
run-deployment: ## For deployment: Creates a deployable version of the model
	$(ACTIVATE) $(CONDA_ENVIRONMENT_NAME) && \
	python -m main --deploy
	$(DEACTIVATE)

# Tests
.PHONY: tests
tests: ## Runs the tests for the application & reports test coverage
	$(ACTIVATE) $(CONDA_ENVIRONMENT_NAME) && \
	coverage run -m pytest -v && \
	coverage report -m
	$(DEACTIVATE)


# MLFlow
.PHONY: create-db-dev
create-db-dev: ## Creates a backend sqlite database to store MLFlow dev data
	$(ACTIVATE) $(CONDA_ENVIRONMENT_NAME) && \
	python -m create_db --env-path=./.env
	$(DEACTIVATE) 


.PHONY: create-db-test
create-db-test: ## Creates a backend sqlite database to store MLFlow test data
	$(ACTIVATE) $(CONDA_ENVIRONMENT_NAME) && \
	python -m create_db --env-path=./.env.test
	$(DEACTIVATE) 

.PHONY: mlflow-ui
mlflow-ui: ## Start the MLFlow webserver
	$(ACTIVATE) $(CONDA_ENVIRONMENT_NAME) && \
	mlflow server \
	--port $(MLFLOW_UI_PORT) \
	--backend-store-uri $(MLFLOW_TRACKING_URI) \
	--default-artifact-root $(ARTIFACT_PATH) 

.PHONY: mlflow-serve-model
mlflow-serve-model: ## Serves the model
	$(ACTIVATE) $(CONDA_ENVIRONMENT_NAME) && \
	mlflow models serve -m $(MODELS_PATH)/logreg_v000 \
	--port $(MLFLOW_MODEL_SERVER_PORT) \
	--no-conda