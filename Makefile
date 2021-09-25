.DEFAULT_GOAL := help

restart: ## Copy configs from repository to conf
	@make -s nginx-restart
	@make -s db-restart
	@make -s ruby-restart

ruby-log: ## Log Server
	@sudo journalctl -f -u isucondition.ruby.service

ruby-restart: ## Restart Server
	@touch ruby/tmp/test.dump
	@rm ruby/tmp/*.dump
	@sudo systemctl daemon-reload
	@cd ruby && bundle 1> /dev/null
	@sudo systemctl restart isucondition.ruby.service
	@echo 'Restart ruby app'

nginx-restart: ## Restart nginx
	@sudo cp -a nginx/* /etc/nginx/
	@sudo rm /var/log/nginx/access.log
	@sudo rm /var/log/nginx/error.log
	@sudo systemctl restart nginx
	@echo 'Restart nginx'

nginx-access-log: ## Tail nginx access.log
	@sudo tail -f /var/log/nginx/access.log

nginx-error-log: ## Tail nginx error.log
	@sudo tail -f /var/log/nginx/error.log

alp: ## Run alp
	@sudo cat /var/log/nginx/access.log | alp ltsv -m '/api/condition/[a-z0-9-]+, /api/isu/[a-z0-9-]+/icon, /api/isu/[a-z0-9-]+/graph, /api/isu/[a-z0-9-]+, /isu/[a-z0-9-]+, /assets/[a-z0-9-]+'

estackprof-top: ## Report by estackprof top
	@cd ruby && bundle exec estackprof top -p app.rb

estackprof-list: ## Report by estackprof list
	@cd ruby && bundle exec estackprof list -f app.rb

db-restart: ## Restart mysql
	@sudo cp -a mysql/* /etc/mysql/
	@sudo systemctl restart mysql
	@echo 'Restart mysql'

myprofiler: ## Run myprofiler
	@myprofiler -user=isucon -password=isucon

.PHONY: help
help:
	@grep -E '^[a-z0-9A-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
