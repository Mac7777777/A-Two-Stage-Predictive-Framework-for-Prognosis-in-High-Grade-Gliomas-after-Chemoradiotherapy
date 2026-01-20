import SimpleITK as sitk
import sys
import os

def apply_mat_transform(fixed_path, moving_seg_path, transform_path, output_path):
    # 读取固定图像（参考空间）
    fixed_img = sitk.ReadImage(fixed_path)
    # 读取待变换的 ROI
    seg_img = sitk.ReadImage(moving_seg_path)

    # 读取 .mat 变换文件（AffineTransform）
    transform = sitk.ReadTransform(transform_path)

    # 应用变换并保存（最近邻插值以保持标签完整性）
    resampled = sitk.Resample(
        seg_img,
        fixed_img,
        transform,
        sitk.sitkNearestNeighbor,
        0.0,
        seg_img.GetPixelID()
    )

    sitk.WriteImage(resampled, output_path)
    print(f"[OK] ROI 已重采样并保存到: {output_path}")

if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("用法: python apply_mat.py <fixed.nii.gz> <roi_in_moving_space.nii.gz> <transform.mat> <output.nii>")
        sys.exit(1)

    fixed_path = sys.argv[1]
    seg_path = sys.argv[2]
    transform_path = sys.argv[3]
    output_path = sys.argv[4]

    # 路径检查
    for f in [fixed_path, seg_path, transform_path]:
        if not os.path.exists(f):
            print(f"[ERROR] 文件不存在: {f}")
            sys.exit(1)

    apply_mat_transform(fixed_path, seg_path, transform_path, output_path)
