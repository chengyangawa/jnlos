#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void show_help() {
    printf("JNL Compiler - Java Net Lava OS 软件编译器\n");
    printf("============================================\n");
    printf("用法: jnl-compiler <输入文件.jnl> <输出文件>\n");
    printf("\n");
    printf(".jnl 文件格式说明:\n");
    printf("[window]\n");
    printf("  title=窗口标题\n");
    printf("  width=宽度\n");
    printf("  height=高度\n");
    printf("\n");
    printf("[widget]\n");
    printf("  type=button|label|entry|textview|separator\n");
    printf("  name=组件名称\n");
    printf("  label=显示文本\n");
    printf("  action=点击动作\n");
    printf("[/widget]\n");
    printf("\n");
    printf("示例:\n");
    printf("[window]\n");
    printf("title=我的应用\n");
    printf("width=400\n");
    printf("height=300\n");
    printf("[widget]\n");
    printf("type=label\n");
    printf("label=欢迎使用 JNL OS!\n");
    printf("[/widget]\n");
}

int main(int argc, char* argv[]) {
    if (argc < 3 || strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0) {
        show_help();
        return 0;
    }
    
    FILE* fp_in = fopen(argv[1], "r");
    if (!fp_in) {
        printf("错误: 无法打开输入文件 %s\n", argv[1]);
        return 1;
    }
    
    FILE* fp_out = fopen(argv[2], "w");
    if (!fp_out) {
        printf("错误: 无法创建输出文件 %s\n", argv[2]);
        fclose(fp_in);
        return 1;
    }
    
    char line[512];
    int in_widget = 0;
    
    fprintf(fp_out, "#!/usr/bin/env jnl-runner\n");
    fprintf(fp_out, "# JNL 文件 - 由 jnl-compiler 生成\n");
    fprintf(fp_out, "# 输入文件: %s\n", argv[1]);
    fprintf(fp_out, "#\n");
    
    while (fgets(line, sizeof(line), fp_in)) {
        line[strcspn(line, "\n")] = 0;
        
        if (strstr(line, "[widget]")) {
            in_widget = 1;
        } else if (strstr(line, "[/widget]")) {
            in_widget = 0;
        }
        
        fprintf(fp_out, "%s\n", line);
    }
    
    fclose(fp_in);
    fclose(fp_out);
    
    printf("编译成功!\n");
    printf("输入文件: %s\n", argv[1]);
    printf("输出文件: %s\n", argv[2]);
    
    return 0;
}
