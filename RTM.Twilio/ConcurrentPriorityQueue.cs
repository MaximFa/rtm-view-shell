namespace RTM.Twilio
{
    public class ConcurrentPriorityQueue<TKey, TValue> where TKey : IComparable<TKey>
    {
        private List<KeyValuePair<TKey, TValue>> heap = new List<KeyValuePair<TKey, TValue>>();
        private readonly object syncRoot = new object();

        public int Count
        {
            get
            {
                lock (syncRoot)
                {
                    return heap.Count;
                }
            }
        }

        public void Enqueue(TKey key, TValue value)
        {
            lock (syncRoot)
            {
                heap.Add(new KeyValuePair<TKey, TValue>(key, value));
                HeapifyUp(heap.Count - 1);
            }
        }

        public bool TryDequeue(out TKey key, out TValue value)
        {
            lock (syncRoot)
            {
                if (heap.Count > 0)
                {
                    var kvp = heap[0];
                    key = kvp.Key;
                    value = kvp.Value;

                    // Move the last item to the root and heapify down
                    heap[0] = heap[heap.Count - 1];
                    heap.RemoveAt(heap.Count - 1);
                    HeapifyDown(0);

                    return true;
                }
                else
                {
                    key = default;
                    value = default;
                    return false;
                }
            }
        }

        public bool TryPeek(out TKey key, out TValue value)
        {
            lock (syncRoot)
            {
                if (heap.Count > 0)
                {
                    var kvp = heap[0];
                    key = kvp.Key;
                    value = kvp.Value;
                    return true;
                }
                else
                {
                    key = default;
                    value = default;
                    return false;
                }
            }
        }

        private void HeapifyUp(int index)
        {
            while (index > 0)
            {
                int parent = (index - 1) / 2;
                if (heap[index].Key.CompareTo(heap[parent].Key) < 0)
                {
                    Swap(index, parent);
                    index = parent;
                }
                else
                {
                    break;
                }
            }
        }

        private void HeapifyDown(int index)
        {
            int lastIndex = heap.Count - 1;
            while (index < lastIndex)
            {
                int leftChild = index * 2 + 1;
                int rightChild = leftChild + 1;
                int smallest = index;

                if (leftChild <= lastIndex && heap[leftChild].Key.CompareTo(heap[smallest].Key) < 0)
                {
                    smallest = leftChild;
                }
                if (rightChild <= lastIndex && heap[rightChild].Key.CompareTo(heap[smallest].Key) < 0)
                {
                    smallest = rightChild;
                }
                if (smallest != index)
                {
                    Swap(index, smallest);
                    index = smallest;
                }
                else
                {
                    break;
                }
            }
        }

        private void Swap(int i, int j)
        {
            var temp = heap[i];
            heap[i] = heap[j];
            heap[j] = temp;
        }
    }
}
