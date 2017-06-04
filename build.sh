#(cd ./3rd/luv; make)
cp ./3rd/luv/luv.so ./

echo export LUA_PATH=$PWD'/?.lua;$LUA_PATH'>run_test.sh
echo export LUA_CPATH=$PWD'/?.so;$LUA_CPATH'>>run_test.sh
echo PATH=$PWD'/3rd/luv/build/:$PATH'>>run_test.sh
echo 'luajit ./test/run_all.lua'>>run_test.sh
