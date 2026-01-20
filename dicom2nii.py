#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
dicom2nii.py
现代版（兼容 pydicom 2.4+）
使用 SimpleITK 将 DICOM 文件夹转换为 NIfTI (.nii.gz)
"""

import os
import sys
import traceback
import SimpleITK as sitk


def convert_dicom_to_nifti(dicom_dir, output_path):
    """
    将 DICOM 文件夹转换为 NIfTI 文件
    """
    print(f"[INFO] DICOM 输入路径: {dicom_dir}")
    print(f"[INFO] 输出文件路径: {output_path}")

    if not os.path.exists(dicom_dir):
        print(f"[ERROR] 输入路径不存在: {dicom_dir}")
        sys.exit(1)

    # 输出目录
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    try:
        # 读取 DICOM 序列
        reader = sitk.ImageSeriesReader()
        dicom_names = reader.GetGDCMSeriesFileNames(dicom_dir)
        if not dicom_names:
            print(f"[ERROR] 未找到任何 DICOM 文件: {dicom_dir}")
            sys.exit(2)

        print(f"[INFO] 找到 {len(dicom_names)} 个 DICOM 文件")

        reader.SetFileNames(dicom_names)
        image = reader.Execute()

        # 写出 NIfTI 文件 (.nii.gz)
        sitk.WriteImage(image, output_path, True)

        if os.path.exists(output_path):
            print(f"[OK] 转换成功: {output_path}")
        else:
            print(f"[ERROR] 转换失败: 未生成文件 {output_path}")
            sys.exit(3)

    except Exception as e:
        print("[ERROR] 转换过程中发生异常：")
        traceback.print_exc()
        sys.exit(4)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("用法: python dicom2nii.py <dicom_folder> <output_file>")
        sys.exit(1)

    dicom_folder = sys.argv[1]
    output_file = sys.argv[2]

    convert_dicom_to_nifti(dicom_folder, output_file)
