fmt:
	tofu fmt -recursive
set_env:
	ls -la; source .env
tf_init:set_env
	cd terraform; tofu init --upgrade
tf_plan: set_env
	cd terraform; tofu plan
tf_apply: set_env
	cd terraform; tofu apply
tf_destroy: set_env
	cd terraform; tofu destroy -auto-approve