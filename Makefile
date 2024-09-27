include .env

daily:
	curl -X POST \
		-H "Authorization: token $(TOKEN)" \
		-H "Accept: application/vnd.github.v3+json" \
		https://api.github.com/repos/sunkenquest/autosheet-gen-bot/actions/workflows/run-bash-daily.yml/dispatches \
		-d '{"ref":"main"}'

weekly-pool:
	curl -X POST \
		-H "Authorization: token $(TOKEN)" \
		-H "Accept: application/vnd.github.v3+json" \
		https://api.github.com/repos/sunkenquest/autosheet-gen-bot/actions/workflows/run-bash-weekly-pool.yml/dispatches \
		-d '{"ref":"main"}'

weekly-sum:
	curl -X POST \
		-H "Authorization: token $(TOKEN)" \
		-H "Accept: application/vnd.github.v3+json" \
		https://api.github.com/repos/sunkenquest/autosheet-gen-bot/actions/workflows/run-bash-weekly-summarize.yml/dispatches \
		-d '{"ref":"main"}'

clear:
	curl -X POST \
		-H "Authorization: token $(TOKEN)" \
		-H "Accept: application/vnd.github.v3+json" \
		https://api.github.com/repos/sunkenquest/autosheet-gen-bot/actions/workflows/run-bash-empty-txts.yml/dispatches \
		-d '{"ref":"main"}'