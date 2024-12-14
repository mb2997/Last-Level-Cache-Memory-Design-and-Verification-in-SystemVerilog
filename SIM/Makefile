#Makefile
PKG=../PKG/*
TB=../TB/*
TB_MODULE=cache

TRACE_FILE ?= rwims.din
MODE ?= SILENT
VERBOSITY ?= 2

lib :
	vlib work
	@echo "---------------------------------------------"
	@echo "TRACE_FILE is $(TRACE_FILE)"
	@echo "---------------------------------------------"
	
cmp :
	vlog -coveropt 3 +acc +cover $(PKG) $(TB)

sim :
	vsim -coverage -vopt $(TB_MODULE) -sv_seed random -c -do "run -all; exit"

sim_arg:
	vsim -coverage -vopt $(TB_MODULE) -sv_seed random -c -do "run -all; exit" +TRACE_FILE=/TESTCASES/$(TRACE_FILE) +MODE=$(MODE) +VERBOSITY=$(VERBOSITY)

all : lib cmp sim
all_arg : lib cmp sim_arg
