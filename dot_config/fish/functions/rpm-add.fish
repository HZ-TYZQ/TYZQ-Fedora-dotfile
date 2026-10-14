# 把 rpm 包加入本地仓库 (~/.local/share/rpm-repo) 并更新元数据
# 用法: rpm-add 包1.rpm [包2.rpm ...]
function rpm-add --description '把 rpm 包加入本地仓库并更新元数据'
    set --local repo "$HOME/.local/share/rpm-repo"
    cp -v $argv $repo/ || return 1
    createrepo_c --update $repo
end
