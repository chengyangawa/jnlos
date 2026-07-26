#!/usr/bin/env python3
"""
重新打包 Arch Linux bootstrap 为 WSL 可导入的 rootfs.tar
保留原始 Unix 权限位，去掉 root.x86_64/ 前缀
"""
import os
import sys
import time
import zstandard
import tarfile

SRC = r"g:\FEPT\FEPT\A_industry code\Code\OS\Java Net Lava OS\archlinux-bootstrap.tar.zst"
DST = r"g:\FEPT\FEPT\A_industry code\Code\OS\Java Net Lava OS\archlinux-rootfs.tar"
PREFIX = "root.x86_64/"


def main():
    if not os.path.exists(SRC):
        print(f"错误：源文件不存在 {SRC}", file=sys.stderr)
        return 1

    print(f"读取: {SRC}")
    print(f"输出: {DST}")
    file_size = os.path.getsize(SRC)
    print(f"源文件大小: {file_size / 1024 / 1024:.1f} MB")

    # 用 zstandard 流式解压，配合 tarfile 流式读取
    count = 0
    skipped = 0
    start = time.time()
    last_report = start

    with open(SRC, 'rb') as f_in:
        dctx = zstandard.ZstdDecompressor()
        with dctx.stream_reader(f_in) as reader:
            # tarfile 流式模式（r|）不支持 seek，必须用 addfile 顺序写入
            with tarfile.open(fileobj=reader, mode='r|', format=tarfile.GNU_FORMAT) as tar_in:
                with tarfile.open(DST, 'w', format=tarfile.GNU_FORMAT) as tar_out:
                    for member in tar_in:
                        # 跳过非 root.x86_64/ 前缀的条目
                        if not member.name.startswith(PREFIX):
                            skipped += 1
                            continue

                        # 去掉前缀
                        new_name = member.name[len(PREFIX):]
                        if not new_name:
                            continue  # 跳过 root.x86_64/ 本身

                        member.name = new_name

                        # 提取文件内容并写入新 tar
                        if member.islnk():
                            # 硬链接：修正 linkname 前缀
                            if member.linkname.startswith(PREFIX):
                                member.linkname = member.linkname[len(PREFIX):]
                            tar_out.addfile(member)
                        elif member.issym():
                            # 符号链接：linkname 通常是相对路径，不需处理
                            tar_out.addfile(member)
                        elif member.isfile():
                            f = tar_in.extractfile(member)
                            tar_out.addfile(member, f)
                        else:
                            # 目录、设备文件等
                            tar_out.addfile(member)

                        count += 1
                        if count % 5000 == 0:
                            now = time.time()
                            if now - last_report > 5:
                                elapsed = now - start
                                print(f"  已处理 {count} 个文件... ({elapsed:.0f}s)")
                                last_report = now

    elapsed = time.time() - start
    out_size = os.path.getsize(DST)
    print(f"\n完成！")
    print(f"  处理文件数: {count}")
    print(f"  跳过条目数: {skipped}")
    print(f"  耗时: {elapsed:.1f}s")
    print(f"  输出大小: {out_size / 1024 / 1024:.1f} MB")
    return 0


if __name__ == '__main__':
    sys.exit(main())
