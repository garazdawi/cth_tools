all: compile test
	echo "Done"

test: compile
	ct_run -noshell -pa ebin -ct_hooks cth_junit -logdir logs -dir test

compile:
	./rebar compile