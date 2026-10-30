import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import javax.imageio.ImageIO;

/** Regenerates Android and web launcher icons from one branding PNG. Requires Java 17+. */
public class GenerateAppIcons {
    private static final String SOURCE = "apps/client/assets/branding/trinktribunal_app_icon.png";
    private static final String ANDROID = "apps/client/android/app/src/main/res/";
    private static final String WEB = "apps/client/web/";

    public static void main(String[] args) throws IOException {
        System.setProperty("java.awt.headless", "true");
        Path root = Path.of("").toAbsolutePath();
        Path sourceFile = root.resolve(SOURCE);
        if (!Files.isRegularFile(sourceFile)) {
            throw new IOException("App icon source not found: " + sourceFile + " (run from repo root)");
        }
        BufferedImage source = ImageIO.read(sourceFile.toFile());
        if (source == null || source.getWidth() != source.getHeight()) {
            throw new IOException("App icon must be a readable square PNG: " + sourceFile);
        }

        String[] densities = {"mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"};
        int[] sizes = {48, 72, 96, 144, 192};
        for (int i = 0; i < sizes.length; i++) {
            write(root, ANDROID + "mipmap-" + densities[i] + "/ic_launcher.png",
                    icon(source, sizes[i], 0.86));
        }
        write(root, ANDROID + "drawable-nodpi/ic_launcher_foreground.png", icon(source, 432, 0.69));
        write(root, WEB + "favicon.png", resize(source, 48));
        for (int size : new int[]{192, 512}) {
            write(root, WEB + "icons/Icon-" + size + ".png", icon(source, size, 0.86));
            write(root, WEB + "icons/Icon-maskable-" + size + ".png", icon(source, size, 0.76));
        }
        System.out.println("Generated 11 launcher icons from " + SOURCE);
    }

    private static BufferedImage icon(BufferedImage source, int size, double scale) {
        BufferedImage canvas = new BufferedImage(size, size, BufferedImage.TYPE_INT_RGB);
        for (int y = 0; y < size; y++) {
            for (int x = 0; x < size; x++) {
                double distance = Math.hypot(x - (size - 1) / 2.0, y - (size - 1) / 2.0);
                double weight = Math.pow(1 - Math.min(1, distance / (size * 0.72)), 1.3);
                int red = (int) Math.round(53 + 82 * weight);
                int green = (int) Math.round(1 + 2 * weight);
                int blue = (int) Math.round(3 + 4 * weight);
                canvas.setRGB(x, y, (red << 16) | (green << 8) | blue);
            }
        }
        int n = (int) Math.round(size * scale);
        BufferedImage layer = resize(source, n);
        int offset = (size - n) / 2;
        double fade = Math.max(1.0, n * 0.055);
        for (int y = 0; y < n; y++) {
            for (int x = 0; x < n; x++) {
                double t = Math.max(0, Math.min(1.0,
                        Math.min(Math.min(x, y), Math.min(n - 1 - x, n - 1 - y)) / fade));
                double blend = t * t * (3 - 2 * t);
                int src = layer.getRGB(x, y);
                blend *= ((src >>> 24) & 255) / 255.0;
                int targetX = offset + x;
                int targetY = offset + y;
                int bg = canvas.getRGB(targetX, targetY);
                int r = channel(bg, src, 16, blend);
                int g = channel(bg, src, 8, blend);
                int b = channel(bg, src, 0, blend);
                canvas.setRGB(targetX, targetY, (r << 16) | (g << 8) | b);
            }
        }
        return canvas;
    }

    private static int channel(int background, int foreground, int shift, double blend) {
        int a = (background >>> shift) & 255;
        int b = (foreground >>> shift) & 255;
        return (int) Math.round(a * (1 - blend) + b * blend);
    }

    private static BufferedImage resize(BufferedImage source, int size) {
        BufferedImage resized = new BufferedImage(size, size, BufferedImage.TYPE_INT_ARGB);
        Graphics2D graphics = resized.createGraphics();
        graphics.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC);
        graphics.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
        graphics.drawImage(source, 0, 0, size, size, null);
        graphics.dispose();
        return resized;
    }

    private static void write(Path root, String relative, BufferedImage image) throws IOException {
        Path path = root.resolve(relative);
        Files.createDirectories(path.getParent());
        if (!ImageIO.write(image, "png", path.toFile())) {
            throw new IOException("Could not write icon " + relative);
        }
    }
}
