interface Props {
  src: string;
  width: number;
  quality?: number;
}
export default function imageLoader({ src, width, quality }: Props) {
  // Return the complete URL with the required parameters
  return `${src}?w=${width}&q=${quality || 75}`
}