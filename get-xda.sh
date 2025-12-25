#!/bin/sh
# debian ubuntu redhat 安装模式共用此脚本
# alpine 未用到此脚本

get_all_disks() {
    # shellcheck disable=SC2010
    ls /sys/block/ | grep -Ev '^(loop|sr|nbd)'
}

get_xda() {
    # 1. 尝试按原逻辑获取默认硬盘 (Default Choice)
    eval "$(grep -o 'extra_main_disk=[^ ]*' /proc/cmdline | sed 's/^extra_//')"
    
    local default_xda=""
    local all_disks
    all_disks=$(get_all_disks)

    # 尝试找到默认硬盘
    if [ -n "$main_disk" ]; then
        for disk in $all_disks; do
            if fdisk -l "/dev/$disk" | grep -iq "$main_disk"; then
                default_xda="$disk"
                break
            fi
        done
    fi

    # 2. 显示硬盘列表菜单 (输出到 stderr 以免污染函数返回结果)
    echo "==================================================" >&2
    echo "              硬盘选择 / Disk Selection           " >&2
    echo "==================================================" >&2

    local i=1
    for disk in $all_disks; do
        # 获取硬盘描述信息 (例如: 50 GiB, 53687091200 bytes, 104857600 sectors)
        local info
        info=$(fdisk -l "/dev/$disk" 2>/dev/null | grep "^Disk /dev/$disk" | cut -d: -f2- | sed 's/^ //')
        echo "  [$i] $disk  |  $info" >&2
        
        # 动态创建变量 disk_1, disk_2 等映射硬盘名
        eval "disk_$i=$disk"
        i=$((i+1))
    done
    echo "==================================================" >&2

    # 3. 交互逻辑：30秒超时
    local prompt_msg="请输入序号或硬盘名 (30秒后自动选择默认: ${default_xda:-无}): "
    echo -n "$prompt_msg" >&2
    
    local choice
    # read -t 30 实现30秒超时
    if read -t 30 choice; then
        echo "" >&2 # 补一个换行
    else
        echo "" >&2
        echo "超时！使用默认选项。" >&2
        choice=""
    fi

    local final_disk=""

    # 4. 处理用户输入
    if [ -z "$choice" ]; then
        # 用户未输入，使用默认值
        final_disk="$default_xda"
    elif echo "$choice" | grep -qE '^[0-9]+$'; then
        # 用户输入了数字
        eval "final_disk=\$disk_$choice"
        if [ -z "$final_disk" ]; then
            echo "错误：无效的序号！" >&2
        else
            echo "用户选择了序号 [$choice]: $final_disk" >&2
        fi
    else
        # 用户可能直接输入了 sda, vda 或 /dev/sda
        local clean_name
        clean_name=$(echo "$choice" | sed 's|/dev/||')
        
        # 检查输入的名称是否在所有磁盘列表中
        for d in $all_disks; do
            if [ "$d" = "$clean_name" ]; then
                final_disk="$clean_name"
                echo "用户选择了硬盘: $final_disk" >&2
                break
            fi
        done
    fi

    # 5. 返回结果或报错
    if [ -n "$final_disk" ]; then
        echo "$final_disk"
        return 0
    else
        # 只有在既没有默认盘，用户输入也无效的情况下才会失败
        if [ -z "$main_disk" ] && [ -z "$default_xda" ]; then
            echo 'MAIN_DISK_NOT_FOUND'
        else
            echo 'XDA_NOT_FOUND'
        fi
        return 1
    fi
}

get_xda