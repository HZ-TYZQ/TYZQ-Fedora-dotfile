# rpm-add 只接受 .rpm 文件,tab 补全文件名
complete -c rpm-add --keep-order --description 'RPM 包' --require-parameter -a '(__fish_complete_suffix .rpm)'
